from __future__ import annotations

import argparse
import json
import re
import subprocess
from typing import Any

from evaluation.voice.asr import (
    ASR_SOURCE,
    CLASSIC_SOURCE,
    CORRECTOR_SOURCE,
    FILE_ERROR_SOURCE,
    FILE_RESULT_SOURCE,
    word_error_rate,
    words,
)
from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.common import ROOT, load_catalog
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256

ENGINES = ("speechAnalyzer", "sfSpeechRecognizer")


def _edit_distance(reference: list[str], actual: list[str]) -> int:
    previous = list(range(len(actual) + 1))
    for index, token in enumerate(reference, start=1):
        current = [index]
        for other_index, other in enumerate(actual, start=1):
            current.append(
                min(current[-1] + 1, previous[other_index] + 1, previous[other_index - 1] + (token != other))
            )
        previous = current
    return previous[-1]


def character_error_rate(reference: str, actual: str) -> float:
    expected = list(" ".join(words(reference)))
    received = list(" ".join(words(actual)))
    return _edit_distance(expected, received) / len(expected) if expected else float(bool(received))


def _critical_retention(case: dict[str, Any], actual: str) -> dict[str, bool | None]:
    facts = case["expectedFacts"]
    lowered = actual.casefold()
    received = set(words(actual))
    measurements = [fact for fact in facts if fact["kind"] == "measurement"]
    negations = [fact for fact in facts if fact["kind"] == "negation"]
    sides = [fact["value"] for fact in facts if fact["kind"] == "side"]
    millimeter_forms = {"mm", "millimeter", "millimeters", "мм", "миллиметр", "миллиметра", "миллиметров"}
    centimeter_forms = {"cm", "centimeter", "centimeters", "см", "сантиметр", "сантиметра", "сантиметров"}
    unit_forms = {
        "mm": millimeter_forms,
        "мм": millimeter_forms,
        "cm": centimeter_forms,
        "см": centimeter_forms,
        "cm/s": {"cm/s", "centimeter per second", "centimeters per second", "см/с", "сантиметров в секунду"},
        "см/с": {"cm/s", "centimeter per second", "centimeters per second", "см/с", "сантиметров в секунду"},
        "ml": {"ml", "milliliter", "milliliters", "мл", "миллилитр", "миллилитров"},
        "мл": {"ml", "milliliter", "milliliters", "мл", "миллилитр", "миллилитров"},
    }
    number_retained = (
        all(re.search(rf"(?<!\d){re.escape(str(fact['value']))}(?!\d)", lowered) for fact in measurements)
        if measurements
        else None
    )
    normalized_text = f" {' '.join(words(actual))} "
    unit_retained = (
        all(
            any(
                f" {' '.join(words(form))} " in normalized_text for form in unit_forms.get(fact["unit"], {fact["unit"]})
            )
            for fact in measurements
        )
        if measurements
        else None
    )
    negation_retained = bool(received & {"no", "not", "нет", "не", "без"}) if negations else None
    if sides:
        side_retained = all(
            ("right" in received or any(token.startswith("прав") for token in received))
            if side == "right"
            else ("left" in received or any(token.startswith("лев") for token in received))
            for side in sides
        )
    else:
        side_retained = None
    return {"negation": negation_retained, "side": side_retained, "number": number_retained, "unit": unit_retained}


def _summarize(rows: list[dict[str, Any]]) -> dict[str, Any]:
    ok = [row for row in rows if row["status"] == "ok"]
    return {
        "requested": len(rows),
        "recognized": len(ok),
        "skipped": sum(row["status"] == "skipped" for row in rows),
        "failed": sum(row["status"] == "failed" for row in rows),
        "meanWER": sum(row["wer"] for row in ok) / len(ok) if ok else None,
        "meanCER": sum(row["cer"] for row in ok) / len(ok) if ok else None,
        "criticalRetention": {
            kind: {
                "retained": sum(row["criticalRetention"][kind] is True for row in ok),
                "eligible": sum(row["criticalRetention"][kind] is not None for row in ok),
            }
            for kind in ("negation", "side", "number", "unit")
        },
    }


def run_comparison(mode: str = "quick", *, limit: int | None = None, score_only: bool = False) -> dict[str, Any]:
    directory = AUDIO_OUTPUT_DIR / (mode if limit is None else f"{mode}-smoke-{limit}")
    manifest_path = directory / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    corpus_path = TEXT_OUTPUT_DIR / "regression.jsonl"
    if manifest["regressionSha256"] != file_sha256(corpus_path):
        raise ValueError("Audio and text corpora differ")
    cases = {
        row["id"]: row for line in corpus_path.read_text(encoding="utf-8").splitlines() if (row := json.loads(line))
    }
    _, terms = load_catalog()
    variants = ("clean",) if mode == "quick" else ("clean", "noisy")
    jobs: list[dict[str, Any]] = []
    lookup: dict[str, tuple[dict[str, Any], str, str, bool]] = {}
    unavailable: list[dict[str, Any]] = []
    for entry in manifest["entries"]:
        case = cases[entry["caseId"]]
        for variant in variants:
            if entry["status"] != "ok":
                unavailable.append(
                    {"caseId": case["id"], "variant": variant, "status": "skipped", "reason": "Audio unavailable"}
                )
                continue
            audio_path = ROOT / entry[variant]["path"]
            if file_sha256(audio_path) != entry[variant]["sha256"]:
                raise ValueError(f"Audio hash mismatch: {audio_path}")
            for engine in ENGINES:
                for hints in (False, True):
                    job_id = f"{case['id']}::{variant}::{engine}::{int(hints)}"
                    jobs.append(
                        {
                            "id": job_id,
                            "locale": case["locale"],
                            "audioPath": str(audio_path),
                            "contextualStrings": terms[case["locale"]][case["examinationTypeId"]],
                            "engine": engine,
                            "useHints": hints,
                        }
                    )
                    lookup[job_id] = (case, variant, engine, hints)
    jobs_path = directory / "comparison-jobs.json"
    results_path = directory / "comparison-results.jsonl"
    jobs_path.write_text(json.dumps(jobs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    executable = AUDIO_OUTPUT_DIR / "voice-audio-asr"
    if not score_only:
        subprocess.run(
            [
                "swiftc",
                "-O",
                "-parse-as-library",
                "-module-cache-path",
                str(AUDIO_OUTPUT_DIR / "swift-module-cache"),
                *map(str, (ASR_SOURCE, CORRECTOR_SOURCE, CLASSIC_SOURCE, FILE_RESULT_SOURCE, FILE_ERROR_SOURCE)),
                "-o",
                str(executable),
            ],
            check=True,
        )
        subprocess.run(
            [str(executable), str(jobs_path), str(results_path)], check=True, timeout=max(120, len(jobs) * 40)
        )
    results = [json.loads(line) for line in results_path.read_text(encoding="utf-8").splitlines()]
    if [row["id"] for row in results] != [job["id"] for job in jobs]:
        raise ValueError("ASR results do not match the requested jobs")
    scored: list[dict[str, Any]] = []
    for result in results:
        case, variant, engine, hints = lookup[result["id"]]
        for corrected in (False, True):
            item = {
                "caseId": case["id"],
                "locale": case["locale"],
                "examinationTypeId": case["examinationTypeId"],
                "variant": variant,
                "engine": engine,
                "hints": hints,
                "correction": corrected,
                "status": result["status"],
                "reason": result.get("reason"),
                "elapsedSeconds": result.get("elapsedSeconds"),
            }
            if result["status"] == "ok":
                transcript = result["correctedText" if corrected else "rawText"]
                item.update(
                    text=transcript,
                    wer=word_error_rate(case["spokenText"], transcript),
                    cer=character_error_rate(case["spokenText"], transcript),
                    criticalRetention=_critical_retention(case, transcript),
                )
            scored.append(item)
    by_group: dict[str, Any] = {}
    for locale in ("en", "ru"):
        for variant in variants:
            for engine in ENGINES:
                for hints in (False, True):
                    for corrected in (False, True):
                        key = f"{locale}/{variant}/{engine}/hints={hints}/correction={corrected}"
                        by_group[key] = _summarize(
                            [
                                row
                                for row in scored
                                if row["locale"] == locale
                                and row["variant"] == variant
                                and row["engine"] == engine
                                and row["hints"] == hints
                                and row["correction"] == corrected
                            ]
                        )
    by_type = {
        f"{locale}/{type_id}": {
            f"{engine}/hints={hints}/correction={corrected}": _summarize(
                [
                    row
                    for row in scored
                    if row["locale"] == locale
                    and row["examinationTypeId"] == type_id
                    and row["engine"] == engine
                    and row["hints"] == hints
                    and row["correction"] == corrected
                ]
            )
            for engine in ENGINES
            for hints in (False, True)
            for corrected in (False, True)
        }
        for locale in ("en", "ru")
        for type_id in sorted({case["examinationTypeId"] for case in cases.values()})
    }
    paired_deltas: dict[str, Any] = {}
    for locale in ("en", "ru"):
        for variable, before_filter, after_filter in (
            (
                "hints",
                {"engine": "speechAnalyzer", "hints": False, "correction": True},
                {"engine": "speechAnalyzer", "hints": True, "correction": True},
            ),
            (
                "correction",
                {"engine": "speechAnalyzer", "hints": True, "correction": False},
                {"engine": "speechAnalyzer", "hints": True, "correction": True},
            ),
            (
                "engine",
                {"engine": "sfSpeechRecognizer", "hints": True, "correction": True},
                {"engine": "speechAnalyzer", "hints": True, "correction": True},
            ),
        ):
            before = {
                (row["caseId"], row["variant"]): row
                for row in scored
                if row["locale"] == locale and all(row[key] == value for key, value in before_filter.items())
            }
            after = {
                (row["caseId"], row["variant"]): row
                for row in scored
                if row["locale"] == locale and all(row[key] == value for key, value in after_filter.items())
            }
            pairs = [
                (old, after[key])
                for key, old in before.items()
                if key in after and old["status"] == after[key]["status"] == "ok"
            ]
            paired_deltas[f"{locale}/{variable}"] = {
                "paired": len(pairs),
                "improvedWER": sum(new["wer"] < old["wer"] for old, new in pairs),
                "worsenedWER": sum(new["wer"] > old["wer"] for old, new in pairs),
                "meanWERDelta": sum(new["wer"] - old["wer"] for old, new in pairs) / len(pairs) if pairs else None,
                "criticalRegressions": {
                    kind: sum(
                        old["criticalRetention"][kind] is True and new["criticalRetention"][kind] is False
                        for old, new in pairs
                    )
                    for kind in ("negation", "side", "number", "unit")
                },
            }
    report = {
        "schemaVersion": 1,
        "platform": "macOS",
        "isIOSBaseline": False,
        "audioMode": mode,
        "audioManifestSha256": file_sha256(manifest_path),
        "requestedRecognitionJobs": len(jobs),
        "unavailableAudio": unavailable,
        "byGroup": by_group,
        "byExaminationType": by_type,
        "pairedDeltas": paired_deltas,
        "results": scored,
        "note": "Literal-token retention on synthetic TTS is not a clinical semantic accuracy measure.",
    }
    (directory / "comparison-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    lines = [
        "# Local ASR comparison on synthetic WAV",
        "",
        f"Mode: {mode}; recognition jobs: {len(jobs)}. Each audio file is used by both engines and both hint settings.",
        "The correction variants are scored from the same raw transcript.",
        "",
        "| Locale | Change | Paired | Better WER | Worse WER | Mean Δ WER | Critical regressions |",
        "|---|---|---:|---:|---:|---:|---|",
    ]
    for locale in ("en", "ru"):
        for variable in ("hints", "correction", "engine"):
            delta = paired_deltas[f"{locale}/{variable}"]
            critical = ", ".join(f"{kind}: {count}" for kind, count in delta["criticalRegressions"].items())
            mean_delta = f"{delta['meanWERDelta']:+.4f}" if delta["meanWERDelta"] is not None else "not measured"
            lines.append(
                f"| {locale} | {variable} | {delta['paired']} | {delta['improvedWER']} | "
                f"{delta['worsenedWER']} | {mean_delta} | {critical} |"
            )
    lines.extend(
        [
            "",
            "## By examination type",
            "",
            "| Locale | Type | Analyzer WER, hints off | Analyzer WER, hints on | Corrected WER |",
            "|---|---|---:|---:|---:|",
        ]
    )
    for name, variants_by_type in by_type.items():
        locale, type_id = name.split("/", 1)

        def display(key: str) -> str:
            value = variants_by_type[key]["meanWER"]
            return f"{value:.3f}" if value is not None else "not measured"

        lines.append(
            f"| {locale} | {type_id} | "
            f"{display('speechAnalyzer/hints=False/correction=False')} | "
            f"{display('speechAnalyzer/hints=True/correction=False')} | "
            f"{display('speechAnalyzer/hints=True/correction=True')} |"
        )
    lines.extend(
        [
            "",
            "Critical retention is a literal check of measurement values, units, side words and negation markers. "
            "It does not establish semantic correctness of a medical statement.",
            "Unavailable recognizer results are excluded from WER denominators and remain visible in comparison-report.json.",
            "",
        ]
    )
    (directory / "comparison.md").write_text("\n".join(lines), encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare local ASR engines and vocabulary on the same WAV files")
    parser.add_argument("--mode", choices=("quick", "extended"), default="quick")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--score-only", action="store_true")
    args = parser.parse_args()
    report = run_comparison(args.mode, limit=args.limit, score_only=args.score_only)
    print(f"Recognition jobs: {report['requestedRecognitionJobs']}")
    print(
        f"Report: {AUDIO_OUTPUT_DIR / (args.mode if args.limit is None else f'{args.mode}-smoke-{args.limit}') / 'comparison-report.json'}"
    )


if __name__ == "__main__":
    main()
