from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.common import FIELD_IDS, LABELS
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256


def audit(summary_path: Path, asr_report_path: Path) -> dict[str, Any]:
    """Join a frozen synthetic corpus, one ASR pass and its iOS replay."""
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    report = json.loads(asr_report_path.read_text(encoding="utf-8"))
    runner = json.loads((summary_path.parent / "results.json").read_text(encoding="utf-8"))
    if summary["inputSource"] != "asrReplay" or summary["split"] != "voiceBlind":
        raise ValueError("Expected a voiceBlind ASR replay")
    corpus_path = TEXT_OUTPUT_DIR / "voiceBlind.jsonl"
    manifest_path = AUDIO_OUTPUT_DIR / summary["audioMode"] / "manifest.json"
    if summary["voiceBlindSha256"] != file_sha256(corpus_path):
        raise ValueError("Corpus hash differs")
    if summary["audioManifestSha256"] != file_sha256(manifest_path):
        raise ValueError("Audio manifest hash differs")
    if report["audioManifestSha256"] != summary["audioManifestSha256"]:
        raise ValueError("ASR report uses another audio manifest")
    if summary["asrReportSha256"] != file_sha256(asr_report_path):
        raise ValueError("ASR report hash differs")
    if report["audioVariant"] != summary["audioVariant"]:
        raise ValueError("ASR variant differs")
    if runner["fixtureASRReportSha256"] != summary["asrReportSha256"]:
        raise ValueError("iOS runner used another ASR report")

    corpus_rows = [json.loads(line) for line in corpus_path.read_text(encoding="utf-8").splitlines()]
    cases = {case["id"]: case for case in corpus_rows}
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    scripts = {entry["caseId"]: entry["ttsText"] for entry in manifest["entries"]}
    asr = {row["caseId"]: row for row in report["results"]}
    raw = {row["id"]: row for row in runner["results"]}
    scored = {row["id"]: row for row in summary["scoredCases"]}
    if any(
        length != len(cases)
        for length in (
            len(corpus_rows),
            len(manifest["entries"]),
            len(report["results"]),
            len(runner["results"]),
            len(summary["scoredCases"]),
        )
    ):
        raise ValueError("Duplicate or missing cases in audit inputs")
    if not (set(cases) == set(scripts) == set(asr) == set(raw) == set(scored)):
        raise ValueError("Cases differ between corpus, audio, ASR and iOS replay")
    if any(row["status"] != "ok" for row in asr.values()):
        raise ValueError("Incomplete ASR report")

    counts: dict[str, dict[str, Counter[str]]] = {
        locale: {field: Counter() for field in FIELD_IDS} for locale in LABELS
    }
    failures = []
    for case_id, case in cases.items():
        row = scored[case_id]
        result = raw[case_id]["goldTextParse"]
        if row["locale"] != case["locale"] or row["examinationTypeId"] != case["examinationTypeId"]:
            raise ValueError(f"Case metadata differ: {case_id}")
        if row["goldTextStatus"] != result["status"]:
            raise ValueError(f"Replay status differs: {case_id}")
        expected = case["expectedFields"]
        actual = result.get("fields", {})
        proposed = set(actual)
        wrong = set(row["goldText"]["equivalentWrongFields"]) if result["status"] == "ok" else set(expected)
        warned = set(row["goldText"]["warnedFields"]) if result["status"] == "ok" else set()
        errors = []
        for field, label in zip(FIELD_IDS, LABELS[case["locale"]], strict=True):
            if field not in expected and field not in proposed:
                continue
            if field not in expected:
                category = "falseFill"
            elif field not in proposed:
                category = "missing"
            elif field not in wrong:
                category = "correct"
            elif field in warned:
                category = "warnedWrong"
            else:
                category = "unwarnedWrong"
            counts[case["locale"]][field][category] += 1
            if category == "correct":
                continue
            errors.append(
                {
                    "field": field,
                    "category": category,
                    "expected": expected.get(field),
                    "actual": actual.get(field),
                    "exactLabelAnywhereInASR": re.search(
                        rf"(?<!\w){re.escape(label)}(?!\w)", asr[case_id]["correctedText"], re.IGNORECASE
                    )
                    is not None,
                }
            )
        if errors or result["status"] != "ok":
            failures.append(
                {
                    "id": case_id,
                    "locale": case["locale"],
                    "scenario": case["scenario"],
                    "parseStatus": result["status"],
                    "ttsText": scripts[case_id],
                    "asrText": asr[case_id]["correctedText"],
                    "errors": errors,
                }
            )
    return {
        "schemaVersion": 1,
        "sourceSummarySha256": file_sha256(summary_path),
        "asrReportSha256": file_sha256(asr_report_path),
        "audioVariant": summary["audioVariant"],
        "recognizer": report["recognizer"],
        "cases": len(cases),
        "byLocale": {
            locale: {field: dict(counter) for field, counter in fields.items()} for locale, fields in counts.items()
        },
        "failures": failures,
        "note": "Exact label presence is descriptive, not proof that an ASR label error caused the field error.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Inspect field errors in a synthetic ASR replay")
    parser.add_argument("summary", type=Path)
    parser.add_argument("asr_report", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = audit(args.summary, args.asr_report)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Audited {result['cases']} cases; {len(result['failures'])} have field errors or failed to parse")
    print(f"Output: {args.output}")


if __name__ == "__main__":
    main()
