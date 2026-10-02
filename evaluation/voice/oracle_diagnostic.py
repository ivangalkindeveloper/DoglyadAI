from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from evaluation.voice.score_candidate import FIELDS

CATEGORIES = ("bothCorrect", "oracleOnly", "asrOnly", "bothWrong")


def compare(oracle: dict[str, Any], candidate: dict[str, Any]) -> dict[str, Any]:
    if oracle.get("inputSource") != "originalText" or candidate.get("inputSource") not in ("originalText", "asrReplay"):
        raise ValueError("Compare original TTS text with original audio or a fixed ASR replay")
    if oracle.get("audioMode") != "extended-v2" or candidate.get("audioMode") != "extended-v2":
        raise ValueError("Both runs must use extended-v2")
    for key in ("regressionSha256", "audioManifestSha256", "audioVariant"):
        if oracle.get(key) != candidate.get(key):
            raise ValueError(f"Runs disagree on {key}")
    oracle_rows = {row["id"]: row for row in oracle["scoredCases"]}
    candidate_rows = {row["id"]: row for row in candidate["scoredCases"]}
    if len(oracle_rows) != len(oracle["scoredCases"]) or len(candidate_rows) != len(candidate["scoredCases"]):
        raise ValueError("Duplicate case IDs")
    if oracle_rows.keys() != candidate_rows.keys():
        raise ValueError("Runs contain different case IDs")
    replay = candidate["inputSource"] == "asrReplay"
    candidate_status_key = "goldTextStatus" if replay else "speechAnalyzerParseStatus"
    candidate_score_key = "goldText" if replay else "speechAnalyzer"

    by_locale: dict[str, Any] = {}
    examples: dict[str, dict[str, list[str]]] = {}
    for locale in ("en", "ru"):
        rows = [
            (oracle_rows[id], candidate_rows[id]) for id in sorted(oracle_rows) if oracle_rows[id]["locale"] == locale
        ]
        categories = {field: Counter() for field in FIELDS}
        examples[locale] = {category: [] for category in CATEGORIES}
        oracle_exact = candidate_exact = 0
        oracle_failed = candidate_failed = 0
        for source, recognized in rows:
            if (
                source["locale"] != recognized["locale"]
                or source["examinationTypeId"] != recognized["examinationTypeId"]
            ):
                raise ValueError(f"Case metadata differs: {source['id']}")
            if source["goldTextStatus"] != "ok":
                oracle_failed += 1
            else:
                oracle_exact += source["goldText"]["equivalentExactCase"]
            if recognized[candidate_status_key] != "ok":
                candidate_failed += 1
            else:
                candidate_exact += recognized[candidate_score_key]["equivalentExactCase"]
            for field in FIELDS:
                oracle_ok = source["goldTextStatus"] == "ok" and source["goldText"]["equivalentMatches"][field]
                candidate_ok = (
                    recognized[candidate_status_key] == "ok"
                    and recognized[candidate_score_key]["equivalentMatches"][field]
                )
                category = (
                    "bothCorrect"
                    if oracle_ok and candidate_ok
                    else "oracleOnly"
                    if oracle_ok
                    else "asrOnly"
                    if candidate_ok
                    else "bothWrong"
                )
                categories[field][category] += 1
                if category != "bothCorrect" and len(examples[locale][category]) < 12:
                    examples[locale][category].append(f"{source['id']}:{field}")
        by_locale[locale] = {
            "cases": len(rows),
            "oracleEquivalentExactCases": oracle_exact,
            "candidateEquivalentExactCases": candidate_exact,
            "oracleParseFailures": oracle_failed,
            "candidateParseFailures": candidate_failed,
            "fields": {field: {category: categories[field][category] for category in CATEGORIES} for field in FIELDS},
        }
    return {
        "schemaVersion": 1,
        "regressionSha256": oracle["regressionSha256"],
        "audioManifestSha256": oracle["audioManifestSha256"],
        "audioVariant": oracle["audioVariant"],
        "candidateInputSource": candidate["inputSource"],
        "candidateASRReportSha256": candidate.get("asrReportSha256"),
        "byLocale": by_locale,
        "examples": examples,
    }


def write_report(result: dict[str, Any], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# Audio v2: parser and ASR contribution",
        "",
        "Oracle input is the intended TTS script, not a verified human transcript. Its spelled-out dates and measurements",
        "can be harder for the parser than the digit-form text returned by ASR. Both-wrong fields cannot be assigned",
        "to one component. Counts use numeric and unit-equivalent description scoring.",
        "",
    ]
    for locale, metrics in result["byLocale"].items():
        lines.extend(
            [
                f"## {locale}",
                "",
                f"Complete forms: intended TTS text {metrics['oracleEquivalentExactCases']}/{metrics['cases']}; "
                f"ASR text {metrics['candidateEquivalentExactCases']}/{metrics['cases']}.",
                "",
                "| Field | Both correct | Only intended text correct | Only ASR text correct | Both wrong |",
                "|---|---:|---:|---:|---:|",
            ]
        )
        for field, counts in metrics["fields"].items():
            lines.append(
                f"| {field} | {counts['bothCorrect']} | {counts['oracleOnly']} | "
                f"{counts['asrOnly']} | {counts['bothWrong']} |"
            )
        lines.append("")
    output.with_suffix(".md").write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare intended TTS text and physical-device ASR parse")
    parser.add_argument("oracle", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = compare(
        json.loads(args.oracle.read_text(encoding="utf-8")),
        json.loads(args.candidate.read_text(encoding="utf-8")),
    )
    write_report(result, args.output)
    print(args.output.with_suffix(".md"))


if __name__ == "__main__":
    main()
