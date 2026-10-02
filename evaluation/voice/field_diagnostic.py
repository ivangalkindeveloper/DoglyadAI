from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.score_candidate import FIELDS

POTENTIALLY_AUTOMATIC = frozenset(("examinationNumber", "patientGender", "patientWeightKG"))


def diagnose(summary_path: Path) -> dict[str, Any]:
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    split = summary["split"]
    if split not in ("regression", "control", "voiceBlind"):
        raise ValueError(f"Unsupported corpus split: {split}")
    corpus_path = TEXT_OUTPUT_DIR / f"{split}.jsonl"
    expected_hash = summary[
        {"regression": "regressionSha256", "control": "controlSha256", "voiceBlind": "voiceBlindSha256"}[split]
    ]
    if file_sha256(corpus_path) != expected_hash:
        raise ValueError("Summary and corpus hashes differ")
    if summary["inputSource"] != "asrReplay":
        raise ValueError("A saved ASR replay is required")
    corpus = [json.loads(line) for line in corpus_path.read_text(encoding="utf-8").splitlines()]
    cases = {case["id"]: case for case in corpus}
    if len(cases) != len(corpus):
        raise ValueError("Duplicate case IDs in corpus")
    rows = summary["scoredCases"]
    if len(rows) != summary["requestedCases"] or len({row["id"] for row in rows}) != len(rows):
        raise ValueError("Duplicate or missing scored cases")

    by_locale: dict[str, Any] = {}
    for locale in ("en", "ru"):
        counts: dict[str, Counter[str]] = {field: Counter() for field in FIELDS}
        examples: dict[str, dict[str, list[str]]] = {
            field: {kind: [] for kind in ("missing", "warnedWrong", "unwarnedWrong")} for field in FIELDS
        }
        failures: list[str] = []
        for row in rows:
            if row["locale"] != locale:
                continue
            case = cases[row["id"]]
            if case["locale"] != locale or case["examinationTypeId"] != row["examinationTypeId"]:
                raise ValueError(f"Case metadata differ for {row['id']}")
            if row["goldTextStatus"] != "ok":
                failures.append(row["id"])
                continue
            parsed = row["goldText"]
            proposed = set(parsed["proposedFields"])
            warned = set(parsed["warnedFields"])
            wrong = set(parsed["equivalentWrongFields"])
            for field in FIELDS:
                expected = field in case["expectedFields"]
                if not expected:
                    if field in proposed:
                        counts[field]["falseFill"] += 1
                    continue
                if field not in proposed:
                    kind = "missing"
                elif field not in wrong:
                    kind = "correct"
                elif field in warned:
                    kind = "warnedWrong"
                else:
                    kind = "unwarnedWrong"
                counts[field][kind] += 1
                if kind in examples[field] and len(examples[field][kind]) < 3:
                    examples[field][kind].append(row["id"])

        by_locale[locale] = {
            "cases": sum(row["locale"] == locale for row in rows),
            "parseFailures": failures,
            "fields": {field: dict(counts[field]) for field in FIELDS},
            "examples": examples,
            "potentiallyAutomaticWrongWithoutConfidence": sum(
                counts[field]["unwarnedWrong"] for field in POTENTIALLY_AUTOMATIC
            ),
        }
    return {
        "schemaVersion": 1,
        "sourceSummarySha256": file_sha256(summary_path),
        "audioMode": summary["audioMode"],
        "audioVariant": summary["audioVariant"],
        "asrRecognizer": summary["asrRecognizer"],
        "note": "Potential automatic errors ignore confidence and source-quote gates; they are not actual auto-filled fields.",
        "byLocale": by_locale,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Classify field errors in an iOS ASR replay")
    parser.add_argument("summary", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = diagnose(args.summary)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for locale, metrics in result["byLocale"].items():
        print(f"{locale}: {metrics['cases']} cases, {len(metrics['parseFailures'])} parse failures")
        for field, counts in metrics["fields"].items():
            print(f"  {field}: {counts}")
        print(
            f"  potential auto-field errors without confidence: {metrics['potentiallyAutomaticWrongWithoutConfidence']}"
        )


if __name__ == "__main__":
    main()
