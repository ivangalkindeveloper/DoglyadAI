from __future__ import annotations

import json
import re
import unicodedata
from collections import Counter
from pathlib import Path
from typing import Any

from evaluation.voice.generate import OUTPUT_DIR

CRITICAL_TOKENS = {
    "left",
    "right",
    "bilateral",
    "no",
    "not",
    "without",
    "absent",
    "none",
    "не",
    "нет",
    "без",
    "слева",
    "справа",
    "левый",
    "левая",
    "левое",
    "левой",
    "правый",
    "правая",
    "правое",
    "правой",
}
UNITS = {"mm", "cm", "ml", "мм", "см", "мл"}


def tokens(value: str) -> list[str]:
    normalized = unicodedata.normalize("NFKC", value).casefold().replace("ё", "е")
    return re.findall(r"\d+(?:[.,]\d+)?|[^\W\d_]+", normalized, flags=re.UNICODE)


def critical_tokens(words: list[str]) -> Counter[str]:
    return Counter(word for word in words if word in CRITICAL_TOKENS or word in UNITS or word[0].isdigit())


def clinical_description_coverage(expected: str, actual: str | None) -> dict[str, Any]:
    """Check literal fact retention in generated cases, not medical equivalence."""
    reference = tokens(expected)
    if actual is None:
        return {
            "completeLiteralContent": False,
            "missingCriticalTokens": sorted(critical_tokens(reference).elements()),
            "extraCriticalTokens": [],
        }
    proposal = tokens(actual)
    complete = any(
        proposal[start : start + len(reference)] == reference for start in range(len(proposal) - len(reference) + 1)
    )

    reference_critical = critical_tokens(reference)
    proposal_critical = critical_tokens(proposal)
    return {
        "completeLiteralContent": complete,
        "missingCriticalTokens": sorted((reference_critical - proposal_critical).elements()),
        "extraCriticalTokens": sorted((proposal_critical - reference_critical).elements()),
    }


def score_report(report_path: Path) -> dict[str, Any]:
    report = json.loads(report_path.read_text(encoding="utf-8"))
    split = report["fixtureSplit"]
    corpus_path = OUTPUT_DIR / f"{split}.jsonl"
    cases = {
        case["id"]: case for line in corpus_path.read_text(encoding="utf-8").splitlines() if (case := json.loads(line))
    }
    rows = []
    for result in report["results"]:
        case = cases[result["id"]]
        expected = case["expectedFields"].get("examinationDescription")
        if expected is None:
            continue
        parse = result["goldTextParse"]
        actual = parse.get("fields", {}).get("examinationDescription") if parse.get("status") == "ok" else None
        rows.append(
            {
                "id": result["id"],
                "locale": case["locale"],
                "scenario": case["scenario"],
                "proposalPresent": actual is not None,
                **clinical_description_coverage(expected, actual),
            }
        )
    return {
        "split": split,
        "cases": len(rows),
        "proposedDescriptions": sum(row["proposalPresent"] for row in rows),
        "completeLiteralContent": sum(row["completeLiteralContent"] for row in rows),
        "missingCriticalTokenCases": sum(bool(row["missingCriticalTokens"]) for row in rows),
        "proposedWithMissingCriticalTokens": sum(
            row["proposalPresent"] and bool(row["missingCriticalTokens"]) for row in rows
        ),
        "extraCriticalTokenCases": sum(bool(row["extraCriticalTokens"]) for row in rows),
        "rows": rows,
    }


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Score literal clinical-fact retention in voice proposals")
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    result = score_report(args.report)
    print(json.dumps({key: value for key, value in result.items() if key != "rows"}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
