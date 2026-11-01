from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

AUTO_FIELDS = frozenset({"examinationNumber", "patientGender", "patientWeightKG"})
THRESHOLDS = (0.5, 0.6, 0.7, 0.8, 0.85, 0.9, 0.95, 0.98, 0.99, 1.0)
IDENTIFIER_CONFIDENCE = 0.85
QUOTE_CONFIDENCE = 0.7


def _utf16_length(value: str) -> int:
    return len(value.encode("utf-16-le")) // 2


def quote_minimum_confidence(raw_text: str, quote: str, spans: list[dict[str, Any]]) -> float | None:
    if not quote or raw_text.count(quote) != 1:
        return None
    start = _utf16_length(raw_text[: raw_text.index(quote)])
    minimum = 1.0
    found = False
    for character in quote:
        length = _utf16_length(character)
        if not character.isspace():
            for position in range(start, start + length):
                covering = [
                    span["confidence"]
                    for span in spans
                    if span["utf16Start"] <= position < span["utf16Start"] + span["utf16Length"]
                    and isinstance(span["confidence"], (int, float))
                    and 0 <= span["confidence"] <= 1
                ]
                if len(covering) != 1:
                    return None
                minimum = min(minimum, covering[0])
                found = True
        start += length
    return minimum if found else None


def identifier_is_a_distinct_literal(quote: str, value: Any) -> bool:
    if not isinstance(value, str) or not value or quote.count(value) != 1:
        return False
    start = quote.index(value)
    end = start + len(value)
    return (start == 0 or not quote[start - 1].isalnum()) and (end == len(quote) or not quote[end].isalnum())


def evaluate(report: dict[str, Any], summary: dict[str, Any]) -> dict[str, Any]:
    scored = {(row["id"], row["locale"]): row for row in summary["scoredCases"]}
    counts: dict[float, Counter[str]] = {threshold: Counter() for threshold in THRESHOLDS}
    by_field: dict[float, dict[str, Counter[str]]] = {threshold: {} for threshold in THRESHOLDS}
    examples: dict[float, list[dict[str, str]]] = {threshold: [] for threshold in THRESHOLDS}
    observations: list[dict[str, Any]] = []
    diagnostics: Counter[str] = Counter()
    policy_counts: Counter[str] = Counter()
    policy_by_field: dict[str, Counter[str]] = {}
    policy_examples: list[dict[str, str]] = []
    policy_observations: list[dict[str, Any]] = []

    for row in report["results"]:
        result = row["asr"].get("speechAnalyzer/hints=true", {})
        parsed = row["recognizedTextParse"].get("speechAnalyzer", {})
        score = scored.get((row["id"], row["locale"]), {}).get("speechAnalyzer", {})
        if result.get("status") != "ok" or parsed.get("status") != "ok":
            diagnostics["unscoredCases"] += 1
            continue
        for field in parsed.get("fields", {}):
            diagnostics["proposedFields"] += 1
            if field not in AUTO_FIELDS:
                diagnostics["fieldNotInAutomaticSet"] += 1
                continue
            if parsed.get("source") != "labeledDictation":
                diagnostics["notLabeledDictation"] += 1
                continue
            if parsed.get("warnings", {}).get(field):
                diagnostics["hasWarnings"] += 1
                continue
            quote = parsed.get("sourceQuotes", {}).get(field, "")
            raw_text = result["rawText"]
            spans = result.get("confidenceSpans", [])
            if not quote or raw_text.count(quote) != 1:
                diagnostics["noUniqueRawQuote"] += 1
                continue
            if field not in score.get("matches", {}):
                diagnostics["missingGoldFieldMatch"] += 1
                continue
            correct = score["matches"][field] is True

            evidence = quote
            required = QUOTE_CONFIDENCE
            if field == "examinationNumber":
                value = parsed["fields"][field]
                if identifier_is_a_distinct_literal(quote, value):
                    evidence = value
                    required = IDENTIFIER_CONFIDENCE
                else:
                    evidence = ""
            evidence_confidence = quote_minimum_confidence(raw_text, evidence, spans)
            if evidence_confidence is not None and evidence_confidence >= required:
                policy_counts["automatic"] += 1
                field_count = policy_by_field.setdefault(field, Counter())
                field_count["automatic"] += 1
                policy_observations.append(
                    {
                        "id": row["id"],
                        "locale": row["locale"],
                        "field": field,
                        "evidenceConfidence": evidence_confidence,
                        "correct": correct,
                    }
                )
                if correct:
                    policy_counts["correct"] += 1
                    field_count["correct"] += 1
                else:
                    policy_counts["wrong"] += 1
                    field_count["wrong"] += 1
                    policy_examples.append({"id": row["id"], "locale": row["locale"], "field": field})

            confidence = quote_minimum_confidence(raw_text, quote, spans)
            if confidence is None:
                diagnostics["noUniqueCoveredRawQuote"] += 1
                continue
            diagnostics["eligibleWithConfidence"] += 1
            observations.append(
                {
                    "id": row["id"],
                    "locale": row["locale"],
                    "field": field,
                    "minimumConfidence": confidence,
                    "correct": correct,
                }
            )
            for threshold in THRESHOLDS:
                if confidence < threshold:
                    continue
                counts[threshold]["automatic"] += 1
                field_count = by_field[threshold].setdefault(field, Counter())
                field_count["automatic"] += 1
                if correct:
                    counts[threshold]["correct"] += 1
                    field_count["correct"] += 1
                else:
                    counts[threshold]["wrong"] += 1
                    field_count["wrong"] += 1
                    examples[threshold].append({"id": row["id"], "locale": row["locale"], "field": field})

    return {
        "platform": report.get("platform"),
        "deviceModel": report.get("deviceModel"),
        "audioMode": report.get("fixtureAudioMode"),
        "audioVariant": report.get("fixtureAudioVariant"),
        "diagnostics": dict(diagnostics),
        "policy": {
            "identifierConfidence": IDENTIFIER_CONFIDENCE,
            "quoteConfidence": QUOTE_CONFIDENCE,
            "automatic": policy_counts["automatic"],
            "correct": policy_counts["correct"],
            "wrong": policy_counts["wrong"],
            "byField": {field: dict(values) for field, values in policy_by_field.items()},
            "wrongExamples": policy_examples,
        },
        "policyObservations": policy_observations,
        "observations": observations,
        "thresholds": {
            str(threshold): {
                "automatic": counts[threshold]["automatic"],
                "correct": counts[threshold]["correct"],
                "wrong": counts[threshold]["wrong"],
                "byField": {field: dict(values) for field, values in by_field[threshold].items()},
                "wrongExamples": examples[threshold],
            }
            for threshold in THRESHOLDS
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit field-level automatic filling against iOS audio gold labels")
    parser.add_argument("report", type=Path, help="VoiceCandidateTests results.json")
    parser.add_argument("--summary", type=Path, help="score_candidate summary.json (default: beside report)")
    parser.add_argument("--output", type=Path, help="Write the diagnostic JSON here")
    args = parser.parse_args()
    report = json.loads(args.report.read_text(encoding="utf-8"))
    summary_path = args.summary or args.report.with_name("summary.json")
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    result = evaluate(report, summary)
    output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(output, encoding="utf-8")
    print(output, end="")


if __name__ == "__main__":
    main()
