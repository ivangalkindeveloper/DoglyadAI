from __future__ import annotations

import argparse
import json
import math
import re
import statistics
import unicodedata
from pathlib import Path
from typing import Any


def normalized(text: str) -> str:
    return " ".join(re.findall(r"\d+(?:[.,]\d+)?|[^\W\d_]+", text.casefold()))


def without_outer_punctuation(text: str) -> str:
    def separator(character: str) -> bool:
        return character.isspace() or unicodedata.category(character).startswith("P")

    start, end = 0, len(text)
    while start < end and separator(text[start]):
        start += 1
    while end > start and separator(text[end - 1]):
        end -= 1
    return text[start:end]


def field_signals(row: dict[str, Any], evidence: str) -> dict[str, Any] | None:
    raw = row["rawText"]
    first = raw.find(evidence)
    if first < 0 or raw.find(evidence, first + 1) >= 0:
        return None
    end = first + len(evidence)
    cursor = 0
    covering = []
    covered: set[int] = set()
    checks = row.get("asrRechecks", [])
    for index, segment in enumerate(row.get("asrSegments", [])):
        text = re.sub(r"<\|[^|]*\|>", "", segment["text"]).strip()
        if not text:
            continue
        position = raw.find(text, cursor)
        if position < 0:
            continue
        cursor = position + len(text)
        overlap_start, overlap_end = max(first, position), min(end, cursor)
        if overlap_start >= overlap_end:
            continue
        covered.update(range(overlap_start, overlap_end))
        overlap = normalized(raw[overlap_start:overlap_end])
        if not overlap:
            continue
        covering.append(
            {
                **segment,
                "consistent": index < len(checks)
                and f" {overlap} " in f" {normalized(checks[index]['repeatedText'])} ",
            }
        )
    if not covering or any(
        not raw[index].isspace() and (index not in covered or ord(raw[index]) > 0xFFFF) for index in range(first, end)
    ):
        return None
    return {
        "minimumAverageLogProbability": min(item["avgLogprob"] for item in covering),
        "maximumTemperature": max(item["temperature"] for item in covering),
        "maximumCompressionRatio": max(item["compressionRatio"] for item in covering),
        "minimumCompressionRatio": min(item["compressionRatio"] for item in covering),
        "consistentOnRecheck": all(item["consistent"] for item in covering),
    }


def compare_recheck(data: dict[str, Any]) -> dict[str, Any]:
    """Retrospective ablation of the current scalar-only Whisper policy.

    Model outputs and scores stay frozen. This measures the effect on automatic
    eligibility, not the accuracy of a new model run or a changed ASR decoder.
    """
    from evaluation.voice.score_candidate import WIRE_FIELD_IDS

    candidates = []
    scalar_ids = {
        "examination_number",
        "patient_gender",
        "patient_date_of_birth",
        "patient_height_cm",
        "patient_weight_kg",
    }
    mismatch_count = 0
    observed_count = 0
    times = []
    for row in data["results"]:
        if row["status"] != "ok":
            continue
        observed = set(row["automaticFieldIds"])
        computed: set[str] = set()
        observed_count += len(observed)
        if isinstance(row.get("asrRecheckSeconds"), (int, float)):
            times.append(row["asrRecheckSeconds"])
        for proposal in row["response"]["proposals"]:
            field = WIRE_FIELD_IDS[proposal["field_id"]]
            if proposal["field_id"] not in scalar_ids:
                if proposal["field_id"] != "patient_complaints" or without_outer_punctuation(
                    str(proposal["value"]).casefold()
                ) not in {"no complaints", "жалоб нет", "нет жалоб", "жалобы отсутствуют"}:
                    continue
            if proposal["accuracy"] != "full" or proposal.get("warnings"):
                continue
            signal = field_signals(row, proposal["evidence"])
            if not signal or not all(
                math.isfinite(signal[key])
                for key in (
                    "minimumAverageLogProbability",
                    "maximumTemperature",
                    "minimumCompressionRatio",
                    "maximumCompressionRatio",
                )
            ):
                continue
            if (
                signal["minimumAverageLogProbability"] < -0.3
                or signal["maximumTemperature"] != 0
                or signal["minimumCompressionRatio"] <= 0
                or signal["maximumCompressionRatio"] > 2.4
            ):
                continue
            if signal["consistentOnRecheck"]:
                computed.add(field)
            candidates.append(
                {
                    "caseId": row["id"],
                    "pack": row["pack"],
                    "locale": row["locale"],
                    "field": field,
                    "correct": row["score"]["matches"].get(field, False),
                    "retainedWithRecheck": signal["consistentOnRecheck"],
                }
            )
        mismatch_count += len(observed.symmetric_difference(computed))
    with_recheck = [item for item in candidates if item["retainedWithRecheck"]]
    removed = [item for item in candidates if not item["retainedWithRecheck"]]
    return {
        "scope": "Frozen proposals; current scalar-only policy; not a new end-to-end run",
        "cases": len(data["results"]),
        "withRecheck": {
            "automaticFields": len(with_recheck),
            "wrongAutomaticFields": sum(not item["correct"] for item in with_recheck),
        },
        "withoutRecheck": {
            "automaticFields": len(candidates),
            "wrongAutomaticFields": sum(not item["correct"] for item in candidates),
        },
        "removedByRecheck": removed,
        "observedAutomaticFields": observed_count,
        "observedPolicyMismatchFields": mismatch_count,
        "medianRecordedRecheckSeconds": statistics.median(times) if times else None,
    }


def analyze(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text())
    fields = []
    for row in data["results"]:
        if row["status"] != "ok":
            continue
        for proposal in row["response"]["proposals"]:
            from evaluation.voice.score_candidate import WIRE_FIELD_IDS

            field = WIRE_FIELD_IDS[proposal["field_id"]]
            if field not in row["automaticFieldIds"]:
                continue
            signals = field_signals(row, proposal["evidence"])
            fields.append(
                {
                    "caseId": row["id"],
                    "locale": row["locale"],
                    "field": field,
                    "value": proposal["value"],
                    "correct": row["score"]["matches"].get(field, False),
                    "signals": signals,
                }
            )
    options = []
    for threshold in (-1.0, -0.6, -0.4, -0.3, -0.2, -0.1):
        for consistency in (False, True):
            retained = [
                field
                for field in fields
                if (signal := field["signals"])
                and signal["minimumAverageLogProbability"] >= threshold
                and signal["maximumTemperature"] == 0
                and signal["maximumCompressionRatio"] <= 2.4
                and (not consistency or signal["consistentOnRecheck"])
            ]
            options.append(
                {
                    "minimumAverageLogProbability": threshold,
                    "requireRecheck": consistency,
                    "retainedAutomaticFields": len(retained),
                    "wrongAutomaticFields": sum(not f["correct"] for f in retained),
                }
            )
    return {
        "cases": len(data["results"]),
        "eligibleAutomaticFields": len(fields),
        "wrongEligibleAutomaticFields": sum(not field["correct"] for field in fields),
        "missingSignals": sum(field["signals"] is None for field in fields),
        "options": options,
        "fields": fields,
        "recheckComparison": compare_recheck(data),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Measure whether Whisper decoding and repeat signals detect incorrect automatic fields"
    )
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = analyze(args.source)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({key: value for key, value in result.items() if key != "fields"}, indent=2))


if __name__ == "__main__":
    main()
