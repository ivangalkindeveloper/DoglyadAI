from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from evaluation.voice.asr import word_error_rate
from evaluation.voice.audio_reference import report_word_references
from evaluation.voice.comparison import _critical_retention, _summarize, character_error_rate
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.spoken_wer import spoken_normalized_wer


def summarize_device_asr(results_path: Path) -> dict[str, Any]:
    report = json.loads(results_path.read_text(encoding="utf-8"))
    corpus_path = TEXT_OUTPUT_DIR / "regression.jsonl"
    if report["fixtureRegressionSha256"] != file_sha256(corpus_path):
        raise ValueError("iPhone results use another regression corpus")
    cases = {case["id"]: case for case in map(json.loads, corpus_path.read_text(encoding="utf-8").splitlines())}
    word_references = report_word_references(report)
    rows = report["results"]
    if len({row["id"] for row in rows}) != len(rows):
        raise ValueError("Duplicate iPhone case IDs")

    scored: list[dict[str, Any]] = []
    for row in rows:
        case = cases[row["id"]]
        if row["locale"] != case["locale"] or row["examinationTypeId"] != case["examinationTypeId"]:
            raise ValueError("iPhone case metadata differs from corpus")
        for engine in ("speechAnalyzer", "sfSpeechRecognizer"):
            for hints in (False, True):
                result = row["asr"].get(f"{engine}/hints={str(hints).lower()}", {"status": "skipped"})
                for corrected in (False, True):
                    item = {
                        "id": row["id"],
                        "locale": case["locale"],
                        "engine": engine,
                        "hints": hints,
                        "correction": corrected,
                        "status": result["status"],
                    }
                    if result["status"] == "ok":
                        transcript = result["correctedText" if corrected else "rawText"]
                        reference = word_references.get(case["id"], case["spokenText"])
                        item.update(
                            wer=spoken_normalized_wer(reference, transcript, case["locale"])
                            if report.get("fixtureAudioMode") == "extended-v2"
                            else word_error_rate(reference, transcript),
                            literalWer=word_error_rate(reference, transcript),
                            cer=character_error_rate(reference, transcript),
                            criticalRetention=_critical_retention(case, transcript),
                        )
                    scored.append(item)

    by_group = {
        f"{locale}/{engine}/hints={hints}/correction={corrected}": _summarize(
            [
                row
                for row in scored
                if row["locale"] == locale
                and row["engine"] == engine
                and row["hints"] == hints
                and row["correction"] == corrected
            ]
        )
        for locale in ("en", "ru")
        for engine in ("speechAnalyzer", "sfSpeechRecognizer")
        for hints in (False, True)
        for corrected in (False, True)
    }
    by_key = {(row["id"], row["engine"], row["hints"], row["correction"]): row for row in scored}
    hints_comparison: dict[str, Any] = {}
    for locale in ("en", "ru"):
        for engine in ("speechAnalyzer", "sfSpeechRecognizer"):
            pairs = [
                (by_key[case["id"], engine, False, True], by_key[case["id"], engine, True, True])
                for case in cases.values()
                if case["locale"] == locale and (case["id"], engine, False, True) in by_key
            ]
            available = [(before, after) for before, after in pairs if before["status"] == after["status"] == "ok"]
            hints_comparison[f"{locale}/{engine}"] = {
                "paired": len(available),
                "improvedWER": sum(after["wer"] < before["wer"] for before, after in available),
                "worsenedWER": sum(after["wer"] > before["wer"] for before, after in available),
                "meanWERDelta": sum(after["wer"] - before["wer"] for before, after in available) / len(available)
                if available
                else None,
                "lostSide": [
                    before["id"]
                    for before, after in available
                    if before["criticalRetention"]["side"] is True and after["criticalRetention"]["side"] is False
                ],
                "lostNegation": [
                    before["id"]
                    for before, after in available
                    if before["criticalRetention"]["negation"] is True
                    and after["criticalRetention"]["negation"] is False
                ],
                "lostNumber": [
                    before["id"]
                    for before, after in available
                    if before["criticalRetention"]["number"] is True and after["criticalRetention"]["number"] is False
                ],
                "lostUnit": [
                    before["id"]
                    for before, after in available
                    if before["criticalRetention"]["unit"] is True and after["criticalRetention"]["unit"] is False
                ],
            }
    return {
        "schemaVersion": 1,
        "source": str(results_path),
        "sourceSha256": file_sha256(results_path),
        "runId": report.get("runId"),
        "deviceModel": report["deviceModel"],
        "systemVersion": report["systemVersion"],
        "cases": len(rows),
        "byGroup": by_group,
        "hintsComparison": hints_comparison,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Score all ASR variants recorded by an iPhone voice evaluation")
    parser.add_argument("results", type=Path)
    args = parser.parse_args()
    report = summarize_device_asr(args.results)
    output = args.results.parent / "device-asr-summary.json"
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
