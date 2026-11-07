"""Validate retained synthetic answers with the unchanged strict schema and main."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import statistics
import sys

from jsonschema.validators import validator_for

ROOT = Path(__file__).resolve().parent
REPOSITORY = ROOT.parents[2]
sys.path.insert(0, str(REPOSITORY / "backend/main"))

from app.core.configuration.configuration_loader import ConfigurationLoader  # noqa: E402
from app.core.localization.language_code import LanguageCode  # noqa: E402
from app.model.ultrasound.us_examination_request import USExaminationRequest  # noqa: E402
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService  # noqa: E402
from app.service.report.report_generation_service import ReportGenerationService  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("results", type=Path)
    args = parser.parse_args()
    cases = {case["id"]: case for case in json.loads((ROOT / "cases.json").read_text())}
    service = ReportGenerationService(
        ConfigurationLoader(REPOSITORY / "backend/main/config/development").load(),
        MockNeuralModelService(),
    )
    records = [json.loads(line) for line in args.results.read_text().splitlines()]
    validations = []
    for row in records:
        if row["event"] != "request":
            continue
        case = cases[row["case_id"]]
        item = {
            key: case[key]
            for key in (
                "id",
                "model_key",
                "scenario",
                "variant",
                "patient",
                "is_synthetic_image",
            )
        }
        item.update(
            repetition=row["repetition"],
            phase=row["phase"],
            seconds=row["seconds"],
            ttft=row["ttft"],
            schema_valid=False,
            main_valid=False,
            natural_stop=row["done"]
            and row["finish"] == "stop"
            and not row.get("error"),
            over_120_seconds=row["seconds"] > 120,
        )
        try:
            schema = case["payload"]["response_format"]["json_schema"]["schema"]
            validator_for(schema)(schema).validate(json.loads(row["text"]))
            item["schema_valid"] = True
            service.complete(
                row["text"],
                USExaminationRequest.model_validate(case["body"]),
                model_id=case["payload"]["model"],
                language_code=LanguageCode(case["language"]),
            )
            item["main_valid"] = True
        except Exception as error:
            item["validation_error"] = str(getattr(error, "code", type(error).__name__))
        validations.append(item)
    groups = {}
    for item in validations:
        key = (item["model_key"], item["scenario"], item["variant"], item["phase"])
        groups.setdefault(key, []).append(item)
    summary = []
    for key, values in groups.items():
        valid_seconds = [
            v["seconds"]
            for v in values
            if v["main_valid"] and v["schema_valid"] and v["natural_stop"]
        ]
        summary.append(
            {
                "model": key[0],
                "scenario": key[1],
                "variant": key[2],
                "phase": key[3],
                "requests": len(values),
                "median_valid_seconds": statistics.median(valid_seconds)
                if valid_seconds
                else None,
                "median_seconds_including_invalid": statistics.median(
                    v["seconds"] for v in values
                ),
                "median_ttft": statistics.median(
                    v["ttft"] for v in values if v["ttft"] is not None
                ),
                "invalid": sum(
                    not (v["main_valid"] and v["schema_valid"] and v["natural_stop"])
                    for v in values
                ),
            }
        )
    result = {
        "runner_complete": any(row["event"] == "complete" for row in records),
        "validation_scope": "JSON Schema and application content/measurement/remark validators; not a clinical assessment",
        "summary": summary,
        "validations": validations,
    }
    path = args.results.with_suffix(".validation.json")
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(
        json.dumps(
            {
                "requests": len(validations),
                "invalid": sum(
                    not (v["main_valid"] and v["schema_valid"] and v["natural_stop"])
                    for v in validations
                ),
                "runner_complete": result["runner_complete"],
                "output": str(path),
            }
        )
    )


if __name__ == "__main__":
    main()
