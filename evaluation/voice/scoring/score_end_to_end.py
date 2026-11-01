from __future__ import annotations


import argparse
import json
import statistics
from pathlib import Path
from typing import Any

from evaluation.voice.scoring.proposal_field_id import proposal_field_id

from evaluation.voice.runners.asr import word_error_rate
from evaluation.voice.datasets.generate import file_sha256
from evaluation.voice.scoring.score_candidate import WIRE_FIELD_IDS, score_fields
from evaluation.voice.scoring.spoken_wer import SCORER_VERSION, spoken_normalized_wer


def score(source: Path, output: Path) -> dict[str, Any]:
    report = json.loads(source.read_text(encoding="utf-8"))
    rows: list[dict[str, Any]] = []
    ids: set[str] = set()
    for case in report["results"]:
        if case["id"] in ids:
            raise ValueError("Duplicate case result")
        ids.add(case["id"])
        row = {**case}
        # ASR completion is independent of parsing. Legacy rows persist rawText
        # before the parser call, so its presence is evidence of that stage.
        # Empty successful transcripts remain valid measurements.
        row["isASRMeasured"] = report.get("inputMode", "audio") == "audio" and isinstance(case.get("rawText"), str)
        if row["isASRMeasured"]:
            reference = case.get("spokenText", case["inputText"])
            row["rawWER"] = word_error_rate(reference, case["rawText"])
            row["correctedWER"] = word_error_rate(reference, case.get("correctedText", case["rawText"]))
            row["unitNormalizedWER"] = spoken_normalized_wer(reference, case["rawText"], case["locale"])
        if case["status"] == "ok":
            proposals = case["response"]["proposals"]
            fields = {WIRE_FIELD_IDS[proposal_field_id(item)]: item["value"] for item in proposals}
            for field, value in fields.items():
                applied = case["formAfterConfirmation"][field]
                if field in ("patientHeightCM", "patientWeightKG"):
                    applied = float(applied)
                if applied != value:
                    raise ValueError(f"{case['id']}: form did not receive the proposed {field}")
            for field in case["automaticFieldIds"]:
                applied = case["formAfterAutomatic"][field]
                if field in ("patientHeightCM", "patientWeightKG"):
                    applied = float(applied)
                if applied != fields[field]:
                    raise ValueError(f"{case['id']}: automatic form patch did not apply {field}")
            parse = {
                "fields": fields,
                "warnings": {WIRE_FIELD_IDS[proposal_field_id(item)]: item.get("warnings", []) for item in proposals},
                "accuracies": {WIRE_FIELD_IDS[proposal_field_id(item)]: item["accuracy"] for item in proposals},
                "automaticFieldIds": case["automaticFieldIds"],
            }
            row["score"] = score_fields(
                case["expectedFields"], parse, locale=case["locale"], normalize_description=True
            )
        rows.append(row)
    groups: dict[str, Any] = {}
    for pack in sorted({row["pack"] for row in rows}):
        for locale in ("ru", "en"):
            selected = [row for row in rows if row["pack"] == pack and row["locale"] == locale]
            ok = [row for row in selected if row["status"] == "ok"]
            asr_measured = [row for row in selected if row["isASRMeasured"]]
            groups[f"{pack}/{locale}"] = {
                "cases": len(selected),
                "completed": len(ok),
                "expectedFields": sum(len(row["expectedFields"]) for row in selected),
                "correctFields": sum(
                    sum(row["score"]["matches"][field] for field in row["expectedFields"]) for row in ok
                ),
                "exactForms": sum(row["score"]["exactCase"] for row in ok),
                "unitEquivalentCorrectFields": sum(
                    sum(row["score"]["equivalentMatches"][field] for field in row["expectedFields"]) for row in ok
                ),
                "unitEquivalentExactForms": sum(row["score"]["equivalentExactCase"] for row in ok),
                "falseFields": sum(len(row["score"]["falseFilledFields"]) for row in ok),
                "wrongFullFields": sum(len(row["score"]["wrongFullFields"]) for row in ok),
                "automaticFields": sum(len(row["score"]["automaticFields"]) for row in ok),
                "wrongAutomaticFields": sum(len(row["score"]["wrongAutomaticFields"]) for row in ok),
                "falseAutomaticFields": sum(len(row["score"]["falseAutomaticFields"]) for row in ok),
                "asrMeasuredCases": len(asr_measured),
                "asrUnmeasuredCases": len(selected) - len(asr_measured),
                "meanWER": statistics.mean(row["rawWER"] for row in asr_measured) if asr_measured else None,
                "meanUnitNormalizedWER": statistics.mean(row["unitNormalizedWER"] for row in asr_measured)
                if asr_measured
                else None,
                "medianASRSeconds": statistics.median(row["asrSeconds"] for row in asr_measured if "asrSeconds" in row)
                if any("asrSeconds" in row for row in asr_measured)
                else None,
                "medianParseSeconds": statistics.median(row["parseSeconds"] for row in ok) if ok else None,
                "foundationCases": sum(row["foundationCalls"] > 0 for row in selected),
                "serverCases": sum(row["serverAttempts"] > 0 for row in selected),
            }
    result = {
        "schemaVersion": 2,
        "scorerVersion": SCORER_VERSION,
        "inputMode": report.get("inputMode", "audio"),
        "sourceSha256": file_sha256(source),
        "fixtureSha256": report["fixtureSha256"],
        "groups": groups,
        "results": rows,
    }
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="Score actual iPhone voice pipeline output against the frozen gold")
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = score(args.source, args.output)
    print(json.dumps(result["groups"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
