from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.comparison import _critical_retention
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256

SPLIT_HASH_KEYS = {
    "regression": "regressionSha256",
    "voiceBlind": "voiceBlindSha256",
    "freeformDevelopment": "freeformDevelopmentSha256",
}
FACT_KINDS = ("side", "negation", "number", "unit")


def diagnose(report_path: Path) -> dict[str, Any]:
    report = json.loads(report_path.read_text(encoding="utf-8"))
    manifest_path = AUDIO_OUTPUT_DIR / report["audioMode"] / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if report["audioManifestSha256"] != file_sha256(manifest_path):
        raise ValueError("ASR and audio manifest hashes differ")
    split = manifest.get("split", "regression")
    if split not in SPLIT_HASH_KEYS:
        raise ValueError(f"Unsupported split: {split}")
    corpus_path = TEXT_OUTPUT_DIR / f"{split}.jsonl"
    if manifest[SPLIT_HASH_KEYS[split]] != file_sha256(corpus_path):
        raise ValueError("Audio and text corpus hashes differ")
    corpus_rows = [json.loads(line) for line in corpus_path.read_text(encoding="utf-8").splitlines()]
    cases = {case["id"]: case for case in corpus_rows}
    rows = report["results"]
    if len(cases) != len(corpus_rows) or len({(row["caseId"], row["variant"]) for row in rows}) != len(rows):
        raise ValueError("Duplicate case IDs")
    if {row["caseId"] for row in rows} != set(cases):
        raise ValueError("ASR report has missing or extra cases")
    if any(row["status"] != "ok" for row in rows):
        raise ValueError("Incomplete ASR report")
    if any(row["locale"] != cases[row["caseId"]]["locale"] for row in rows):
        raise ValueError("ASR locale differs from corpus")

    by_locale: dict[str, Any] = {}
    for locale in ("en", "ru"):
        subset = [row for row in rows if row["locale"] == locale]
        counts: dict[str, Counter[str]] = {kind: Counter() for kind in FACT_KINDS}
        examples: dict[str, list[str]] = {kind: [] for kind in FACT_KINDS}
        for row in subset:
            retention = _critical_retention(cases[row["caseId"]], row["correctedText"])
            for kind in FACT_KINDS:
                result = retention[kind]
                if result is None:
                    continue
                counts[kind]["eligible"] += 1
                if result:
                    counts[kind]["retained"] += 1
                elif len(examples[kind]) < 5:
                    examples[kind].append(row["caseId"])
        by_locale[locale] = {
            "cases": len(subset),
            "meanCorrectedWER": sum(row["correctedWER"] for row in subset) / len(subset) if subset else None,
            "literalFactRetention": {kind: dict(counts[kind]) for kind in FACT_KINDS},
            "lostFactExamples": examples,
        }
    return {
        "schemaVersion": 1,
        "asrReportSha256": file_sha256(report_path),
        "audioMode": report["audioMode"],
        "audioVariant": report["audioVariant"],
        "recognizer": report["recognizer"],
        "byLocale": by_locale,
        "note": "Literal word presence is a coarse diagnostic, not semantic correctness or field accuracy.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Score literal fact retention in a synthetic ASR report")
    parser.add_argument("report", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = diagnose(args.report)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for locale, values in result["byLocale"].items():
        print(f"{locale}: {values['cases']} cases, WER {values['meanCorrectedWER']:.4f}")
        print(f"  literal fact retention: {values['literalFactRetention']}")


if __name__ == "__main__":
    main()
