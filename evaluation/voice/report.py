from __future__ import annotations

import argparse
import json
import math
import subprocess
from pathlib import Path
from typing import Any

from evaluation.voice.common import ROOT
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.prepare_ios import SOURCE_FILES

OUTPUT_ROOT = ROOT / "build/voice-eval"


def _read(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    state_path = path.parent / "run-state.json"
    if state_path.exists() and json.loads(state_path.read_text(encoding="utf-8"))["status"] != "complete":
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def _candidate_directory(suffix: str, *, physical_only: bool = False, simulator_only: bool = False) -> Path:
    if physical_only and simulator_only:
        raise ValueError("Choose only one iOS platform")
    application = json.loads((ROOT / "backend/main/config/development/application.json").read_text(encoding="utf-8"))
    max_tokens = application["ultrasound"]["examinationNeuralModel"]["maxTokens"]
    platforms = ("device",) if physical_only else ("",) if simulator_only else ("device", "")
    options = [
        OUTPUT_ROOT / f"ios-candidate{'-' + platform if platform else ''}{token_suffix}{suffix}"
        for platform in platforms
        for token_suffix in ("", f"-tokens{max_tokens}")
    ]
    for directory in options:
        if _candidate_inputs_current(_read(directory / "results.json")):
            return directory
    return next((directory for directory in options if _read(directory / "results.json")), options[0])


def _candidate_inputs_current(result: dict[str, Any] | None) -> bool:
    if result is None:
        return False
    hashes = result.get("fixtureSourceFilesSha256")
    if not isinstance(hashes, dict) or set(hashes) != {str(path.relative_to(ROOT)) for path in SOURCE_FILES}:
        return False
    if any(file_sha256(ROOT / path) != digest for path, digest in hashes.items()):
        return False
    if result.get("fixtureApplicationSha256") != file_sha256(ROOT / "backend/main/config/development/application.json"):
        return False
    for code in ("en", "ru"):
        locale_dir = ROOT / "backend/main/config/development" / code
        if (result.get("fixturePromptSha256") or {}).get(code) != file_sha256(locale_dir / "l10n.json"):
            return False
        if (result.get("fixtureContextualStringsSha256") or {}).get(code) != file_sha256(
            locale_dir / "l10n_ultrasound_examination_contextual_strings.json"
        ):
            return False
    return True


def _current_candidate_summary(directory: Path) -> dict[str, Any] | None:
    if not _candidate_inputs_current(_read(directory / "results.json")):
        return None
    return _read(directory / "summary.json")


def _gate(passed: bool | None, detail: str) -> dict[str, str]:
    return {"status": "unmeasured" if passed is None else "pass" if passed else "fail", "detail": detail}


def _fraction(summary: dict[str, Any] | None, locale: str, engine: str) -> tuple[int, int] | None:
    if summary is None or summary.get("requestedCases") != 248:
        return None
    metrics = summary["byLocale"][locale][engine]
    if metrics["scoredCases"] != 124:
        return None
    return metrics["exactCases"], metrics["scoredCases"]


def _percentile(values: list[float], quantile: float) -> float | None:
    if not values:
        return None
    sorted_values = sorted(values)
    position = (len(sorted_values) - 1) * quantile
    lower, upper = math.floor(position), math.ceil(position)
    return sorted_values[lower] + (sorted_values[upper] - sorted_values[lower]) * (position - lower)


def _paired_latency(baseline: dict[str, Any] | None, candidate: dict[str, Any] | None) -> dict[str, Any]:
    if baseline is None or candidate is None:
        return {"baselineP95": None, "candidateP95": None, "pairedCases": 0}
    original = {row["id"]: row for row in baseline["results"]}
    durations: list[tuple[float, float]] = []
    for row in candidate["results"]:
        before = original.get(row["id"])
        if before is None:
            continue
        old_asr = before.get("asr", {})
        old_parse = before.get("recognizedTextParse", {})
        new_asr = row.get("asr", {}).get("speechAnalyzer/hints=true", {})
        new_parse = row.get("recognizedTextParse", {}).get("speechAnalyzer", {})
        if all(stage.get("status") == "ok" for stage in (old_asr, old_parse, new_asr, new_parse)):
            durations.append(
                (
                    float(old_asr["elapsedSeconds"]) + float(old_parse["elapsedSeconds"]),
                    float(new_asr["elapsedSeconds"]) + float(new_parse["elapsedSeconds"]),
                )
            )
    return {
        "baselineP95": _percentile([pair[0] for pair in durations], 0.95),
        "candidateP95": _percentile([pair[1] for pair in durations], 0.95),
        "pairedCases": len(durations),
        "scope": "end of file to parsed proposal, excluding clinician review",
    }


def _field_nonregression(baseline: dict[str, Any] | None, candidate: dict[str, Any] | None) -> dict[str, Any]:
    if baseline is None or candidate is None or baseline.get("regressionSha256") != candidate.get("regressionSha256"):
        return {"pairedCases": 0, "byField": {}}
    old_rows = {row["id"]: row for row in baseline["scoredCases"]}
    pairs = [
        (old_rows[row["id"]], row)
        for row in candidate["scoredCases"]
        if row["id"] in old_rows
        and old_rows[row["id"]].get("recognizedTextStatus") == "ok"
        and row.get("speechAnalyzerParseStatus") == "ok"
    ]
    fields = (
        "patientName",
        "patientGender",
        "patientDateOfBirth",
        "patientHeightCM",
        "patientWeightKG",
        "patientComplaints",
        "examinationDescription",
    )
    return {
        "pairedCases": len(pairs),
        "byField": {
            field: {
                "baselineCorrect": sum(old["recognizedText"]["matches"][field] for old, _ in pairs),
                "candidateCorrect": sum(new["speechAnalyzer"]["matches"][field] for _, new in pairs),
            }
            for field in fields
        },
    }


def build_report() -> dict[str, Any]:
    commit = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True
    ).stdout.strip()
    dirty = bool(
        subprocess.run(
            ["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True, check=True
        ).stdout.strip()
    )
    output = OUTPUT_ROOT / commit
    output.mkdir(parents=True, exist_ok=True)
    physical_baseline = OUTPUT_ROOT / "ios-device"
    physical_candidate = _candidate_directory("", physical_only=True)
    use_physical_pair = _read(physical_baseline / "results.json") is not None and _candidate_inputs_current(
        _read(physical_candidate / "results.json")
    )
    baseline_dir = physical_baseline if use_physical_pair else OUTPUT_ROOT / "ios"
    candidate_dir = physical_candidate if use_physical_pair else _candidate_directory("", simulator_only=True)
    baseline = _read(baseline_dir / "results.json")
    candidate = _read(candidate_dir / "results.json")
    if not _candidate_inputs_current(candidate):
        candidate = None
    baseline_summary = _read(baseline_dir / "summary.json")
    candidate_summary = _read(candidate_dir / "summary.json") if candidate else None
    clean_dir = _candidate_directory("-extended-clean", physical_only=use_physical_pair)
    noisy_dir = _candidate_directory("-extended-noisy", physical_only=use_physical_pair)
    clean = _current_candidate_summary(clean_dir)
    noisy = _current_candidate_summary(noisy_dir)
    control = _current_candidate_summary(_candidate_directory("-control"))
    adversarial = _current_candidate_summary(_candidate_directory("-adversarial"))
    candidate_artifacts = {
        "quick": candidate,
        "clean": _read(clean_dir / "results.json"),
        "noisy": _read(noisy_dir / "results.json"),
        "control": _read(_candidate_directory("-control") / "results.json"),
        "adversarial": _read(_candidate_directory("-adversarial") / "results.json"),
    }
    comparison = _read(OUTPUT_ROOT / "audio/quick/comparison-report.json")
    extended_asr = _read(OUTPUT_ROOT / "audio/extended/asr-report.json")
    fleurs = _read(OUTPUT_ROOT / "fleurs/asr-report.json")
    verification = _read(OUTPUT_ROOT / "verification.json")
    corpus = TEXT_OUTPUT_DIR / "regression.jsonl"
    corpus_hash = file_sha256(corpus) if corpus.exists() else None
    quick_manifest = OUTPUT_ROOT / "audio/quick/manifest.json"
    quick_audio_hash = file_sha256(quick_manifest) if quick_manifest.exists() else None
    same_corpus = (
        baseline is not None
        and candidate is not None
        and corpus_hash is not None
        and (baseline.get("fixtureRegressionSha256") == candidate.get("fixtureRegressionSha256") == corpus_hash)
    )
    same_audio = same_corpus and (
        baseline.get("fixtureAudioManifestSha256") == candidate.get("fixtureAudioManifestSha256") == quick_audio_hash
    )
    gates: dict[str, dict[str, str]] = {}
    gates["sameCorpusAndAudio"] = _gate(
        same_audio if baseline and candidate else None,
        "Baseline and candidate must use identical 62-case WAV and text hashes",
    )
    available_artifacts = [name for name, result in candidate_artifacts.items() if result is not None]
    stale_artifacts = [
        name for name, result in candidate_artifacts.items() if result and not _candidate_inputs_current(result)
    ]
    gates["candidateInputsCurrent"] = _gate(
        not stale_artifacts if len(available_artifacts) == len(candidate_artifacts) else None,
        f"Available artifacts: {', '.join(available_artifacts) or 'none'}; stale inputs: {', '.join(stale_artifacts) or 'none'}",
    )
    field_comparison = _field_nonregression(baseline_summary, candidate_summary)
    if field_comparison["pairedCases"]:
        regressions = [
            field
            for field, counts in field_comparison["byField"].items()
            if counts["candidateCorrect"] < counts["baselineCorrect"]
        ]
        gates["fieldNonregression"] = _gate(
            False if regressions else True if field_comparison["pairedCases"] == 62 else None,
            f"{field_comparison['pairedCases']}/62 paired cases; regressed fields: {', '.join(regressions) or 'none'}",
        )
    else:
        gates["fieldNonregression"] = _gate(None, "No paired parsed forms")
    verified_sources = verification is not None and verification.get("sourceSha256") == {
        str(path.relative_to(ROOT)): file_sha256(path) for path in SOURCE_FILES
    }
    passed_contracts = verification is not None and verification.get("allPassed") is True and verified_sources
    gates["contracts"] = _gate(
        passed_contracts if verification is not None else None,
        "Swift contract tests and backend checks must pass on the current source files",
    )
    if control and control.get("requestedCases") == 248:
        metrics = control["byLocale"]
        scored = all(metrics[locale]["goldTextScoredCases"] == 124 for locale in ("en", "ru"))
        unnoticed = sum(metrics[locale]["goldTextUnnoticedWrongFields"] for locale in ("en", "ru"))
        false_filled = sum(
            len(item["goldText"]["falseFilledFields"])
            for item in control["scoredCases"]
            if item["goldTextStatus"] == "ok"
        )
        gates["controlSafety"] = _gate(
            unnoticed == 0 and false_filled == 0 if scored else None,
            f"{unnoticed} wrong values without a warning; {false_filled} unsupported filled fields in 248 separate-seed control cases"
            if scored
            else "Control parse incomplete; unavailable cases cannot pass",
        )
    else:
        gates["controlSafety"] = _gate(None, "248-case control set has not been run on a capable device")
    gates["untouchedControl"] = _gate(
        None,
        "Control v1 informed an uncertainty-cue fix; an unseen versioned holdout is required for independent validation",
    )
    if adversarial and adversarial.get("requestedCases") == 10:
        metrics = adversarial["byLocale"]
        scored = sum(metrics[locale]["goldTextScoredCases"] for locale in ("en", "ru"))
        unnoticed = sum(metrics[locale]["goldTextUnnoticedWrongFields"] for locale in ("en", "ru"))
        false_filled = sum(
            len(item["goldText"]["falseFilledFields"])
            for item in adversarial["scoredCases"]
            if item["goldTextStatus"] == "ok"
        )
        gates["adversarialSafety"] = _gate(
            unnoticed == 0 and false_filled == 0 if scored == 10 else None,
            f"{scored}/10 parsed; {unnoticed} wrong values without a warning; {false_filled} unsupported filled fields",
        )
    else:
        gates["adversarialSafety"] = _gate(None, "Ten adversarial text cases have not been run")
    for variant, summary, threshold in (("clean", clean, 0.95), ("noisy", noisy, 0.85)):
        for locale in ("en", "ru"):
            result = _fraction(summary, locale, "speechAnalyzer")
            ratio = result[0] / result[1] if result else None
            gates[f"synthetic_{variant}_{locale}"] = _gate(
                ratio >= threshold if ratio is not None else None,
                f"{result[0]}/{result[1]} fully correct forms; threshold {threshold:.0%}"
                if result
                else "Requires all 124 iOS cases for this locale and audio variant",
            )
    if fleurs and fleurs.get("baselineCandidatePaired") == {"en": 100, "ru": 100}:
        nonregression = all(
            fleurs["byLocale"][locale]["candidateWER"] <= fleurs["byLocale"][locale]["baselineWER"]
            and fleurs["byLocale"][locale]["candidateCER"] <= fleurs["byLocale"][locale]["baselineCER"]
            for locale in ("en", "ru")
        )
        gates["naturalSpeechNonregression"] = _gate(
            nonregression, "Paired WER and CER on 100+100 FLEURS test recordings"
        )
    else:
        gates["naturalSpeechNonregression"] = _gate(None, "100+100 paired FLEURS results unavailable")
    latency = _paired_latency(baseline, candidate)
    if latency["pairedCases"] == 62 and latency["baselineP95"] is not None:
        gates["latency"] = _gate(
            latency["candidateP95"] <= latency["baselineP95"] * 1.2,
            f"p95 baseline {latency['baselineP95']:.2f}s, candidate {latency['candidateP95']:.2f}s",
        )
    else:
        gates["latency"] = _gate(None, f"Only {latency['pairedCases']}/62 paired end-to-end cases")
    if comparison is None or comparison["requestedRecognitionJobs"] != 248:
        gates["asrComparison"] = _gate(None, "Four recognition variants on all 62 identical WAVs unavailable")
    else:
        complete = all(metric["recognized"] == metric["requested"] for metric in comparison["byGroup"].values())
        gates["asrComparison"] = _gate(
            True if complete else None,
            "Mac diagnostic comparison of both engines, hints and correction"
            if complete
            else "One or more macOS recognition variants were unavailable; see per-case results",
        )

    report = {
        "schemaVersion": 1,
        "commit": commit,
        "workingTreeDirty": dirty,
        "releaseReady": all(gate["status"] == "pass" for gate in gates.values()),
        "corpusSha256": corpus_hash,
        "quickAudioManifestSha256": quick_audio_hash,
        "gates": gates,
        "latency": latency,
        "fieldComparison": field_comparison,
        "sourceSha256": {
            str(path.relative_to(ROOT)): file_sha256(path)
            for path in (
                ROOT / "evaluation/voice/report.py",
                ROOT / "evaluation/voice/comparison.py",
                ROOT / "evaluation/voice/score_candidate.py",
                ROOT / "evaluation/voice/score_ios.py",
                ROOT / "ios/DoglyadNeuralModel/Examination/DictationProposal.swift",
                ROOT / "ios/DoglyadSpeech/Controller/DSpeechControllerSFSpeechRecognizer.swift",
                ROOT / "ios/DoglyadSpeech/Controller/DSpeechControllerAnalyzer.swift",
                ROOT / "ios/DoglyadSpeech/Controller/DSpeechFileTranscriber.swift",
                ROOT / "ios/DoglyadSpeech/Controller/DSpeechFileRecognizerSFSpeechRecognizer.swift",
                ROOT / "ios/DoglyadNeuralModel/Examination/DictationProposalValidator.swift",
                ROOT / "ios/Doglyad/Application/Module/Scan/ScanSpeech/ScanSpeechViewModel.swift",
            )
        },
        "artifacts": {
            "baseline": str((baseline_dir / "results.json").relative_to(ROOT)) if baseline else None,
            "candidate": str((candidate_dir / "results.json").relative_to(ROOT)) if candidate else None,
            "extendedClean": str((clean_dir / "results.json").relative_to(ROOT)) if clean else None,
            "extendedNoisy": str((noisy_dir / "results.json").relative_to(ROOT)) if noisy else None,
            "comparison": str((OUTPUT_ROOT / "audio/quick/comparison-report.json").relative_to(ROOT))
            if comparison
            else None,
            "extendedASR": str((OUTPUT_ROOT / "audio/extended/asr-report.json").relative_to(ROOT))
            if extended_asr
            else None,
            "fleurs": str((OUTPUT_ROOT / "fleurs/asr-report.json").relative_to(ROOT)) if fleurs else None,
            "adversarial": str((_candidate_directory("-adversarial") / "results.json").relative_to(ROOT))
            if adversarial
            else None,
        },
    }
    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# Voice form evaluation",
        "",
        f"Commit: `{commit}`; working tree dirty: {dirty}.",
        f"Release ready: **{'yes' if report['releaseReady'] else 'no'}**.",
        "",
        "| Gate | Status | Evidence |",
        "|---|---|---|",
    ]
    for key, gate in gates.items():
        lines.append(f"| {key} | {gate['status']} | {gate['detail']} |")
    if baseline_summary and candidate_summary:
        lines.extend(
            [
                "",
                "## iOS quick set",
                "",
                "| Locale | Baseline exact | Candidate exact | Candidate wrong fields without automated warning |",
                "|---|---:|---:|---:|",
            ]
        )
        for locale in ("en", "ru"):
            old = baseline_summary["byLocale"][locale]
            new = candidate_summary["byLocale"][locale]["speechAnalyzer"]
            lines.append(
                f"| {locale} | {old['recognizedTextExactCases']}/{old['recognizedTextScoredCases']} | "
                f"{new['exactCases']}/{new['scoredCases']} | {new['unnoticedWrongFields']} |"
            )
        lines.extend(
            [
                "",
                "An automated warning cannot detect every speech-recognition error. "
                "The app requires the physician to review and select each proposed field.",
            ]
        )
    if field_comparison["pairedCases"]:
        lines.extend(
            [
                "",
                f"## Field accuracy on {field_comparison['pairedCases']} paired completed cases",
                "",
                "| Field | Baseline correct | Candidate correct |",
                "|---|---:|---:|",
            ]
        )
        for field, counts in field_comparison["byField"].items():
            lines.append(f"| {field} | {counts['baselineCorrect']} | {counts['candidateCorrect']} |")
    if fleurs:
        lines.extend(
            [
                "",
                "## Natural speech ASR (FLEURS test)",
                "",
                "| Locale | Paired recordings | Baseline WER/CER | Candidate WER/CER |",
                "|---|---:|---:|---:|",
            ]
        )
        for locale in ("en", "ru"):
            metrics = fleurs["byLocale"][locale]
            if metrics["paired"]:
                lines.append(
                    f"| {locale} | {metrics['paired']}/100 | "
                    f"{metrics['baselineWER']:.3f}/{metrics['baselineCER']:.3f} | "
                    f"{metrics['candidateWER']:.3f}/{metrics['candidateCER']:.3f} |"
                )
            else:
                lines.append(f"| {locale} | 0/100 | not measured | not measured |")
        lines.extend(
            [
                "",
                "Both versions use the unchanged SpeechAnalyzer without domain hints; "
                "separate runs verify stability on general speech.",
            ]
        )
    if comparison:
        lines.extend(
            [
                "",
                "## Synthetic ASR changes",
                "",
                "| Locale | Change | Paired files | Better/Worse WER | Mean Δ WER |",
                "|---|---|---:|---:|---:|",
            ]
        )
        for locale in ("en", "ru"):
            for variable in ("hints", "correction", "engine"):
                delta = comparison["pairedDeltas"][f"{locale}/{variable}"]
                average = f"{delta['meanWERDelta']:+.4f}" if delta["meanWERDelta"] is not None else "not measured"
                lines.append(
                    f"| {locale} | {variable} | {delta['paired']} | "
                    f"{delta['improvedWER']}/{delta['worsenedWER']} | {average} |"
                )
        lines.extend(["", "Full type-level and critical-token results: [comparison](../audio/quick/comparison.md)."])
    if extended_asr:
        lines.extend(
            [
                "",
                "## Extended synthetic ASR diagnostic (macOS)",
                "",
                "| Locale | Audio | Recognized | Mean corrected WER |",
                "|---|---|---:|---:|",
            ]
        )
        for locale in ("en", "ru"):
            for variant in ("clean", "noisy"):
                rows = [
                    row
                    for row in extended_asr["results"]
                    if row["locale"] == locale and row["variant"] == variant and row["status"] == "ok"
                ]
                average = sum(row["correctedWER"] for row in rows) / len(rows) if rows else None
                lines.append(
                    f"| {locale} | {variant} | {len(rows)}/124 | {average:.3f} |"
                    if average is not None
                    else f"| {locale} | {variant} | 0/124 | not measured |"
                )
    lines.extend([""])
    if _candidate_inputs_current(candidate_artifacts["control"]):
        lines.append(
            "The control set exposed missing uncertainty cues and was used to improve the parser; "
            "it is no longer an untouched holdout. A new holdout is needed for independent final validation."
        )
    else:
        lines.append("The independent control set remains reserved until tuning on the regression set is complete.")
    lines.extend(
        [
            "Unmeasured cases do not pass. Synthetic WAV and FLEURS general speech do not prove clinical dictation accuracy.",
            "No patient audio or text is collected by this evaluation.",
            "",
        ]
    )
    (output / "report.md").write_text("\n".join(lines), encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Build reproducible voice quality gates from local artifacts")
    parser.add_argument("--strict", action="store_true", help="Fail if any release gate did not pass")
    args = parser.parse_args()
    report = build_report()
    print(f"Report: {OUTPUT_ROOT / report['commit'] / 'report.md'}")
    print(f"Release ready: {report['releaseReady']}")
    if args.strict and not report["releaseReady"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
