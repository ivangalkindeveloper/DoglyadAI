"""Validate frozen structured outputs without registering a test model in the app."""

from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import re
import sys

from jsonschema.validators import validator_for

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "backend/main"))

from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.localization.language_code import LanguageCode
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.service.dictation.voice_form_validator import VoiceFormValidator
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService
from app.service.report.report_generation_service import ReportGenerationService

ROOT = Path(__file__).resolve().parents[4]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--cases", type=Path, required=True)
    parser.add_argument("--reference", type=Path)
    args = parser.parse_args()
    cases = {case["id"]: case for case in json.loads(args.cases.read_text())}
    baseline = {}
    if args.reference:
        baseline = {
            row["id"]: row
            for line in args.reference.read_text().splitlines()
            if "id" in (row := json.loads(line))
        }
    configuration = ConfigurationLoader(ROOT / "backend/main/config/development").load()
    reports = ReportGenerationService(configuration, MockNeuralModelService())
    voice = VoiceFormValidator(configuration.voice_source_localization(LanguageCode.RU))
    expected_fields = {
        "patient_name": "Иванов Иван Иванович",
        "patient_height_cm": 180,
        "patient_weight_kg": 80,
        "patient_complaints": "дискомфорт в области шеи",
    }
    results = []
    for path in sorted(args.directory.glob("*.jsonl")):
        for line in path.read_text().splitlines():
            row = json.loads(line)
            if "id" not in row:
                continue
            case = cases[row["id"]]
            result = {
                key: row[key]
                for key in ("id", "finish", "seconds", "usage", "error")
                if key in row
            }
            result.update(runtime=path.stem, schema_valid=False, main_valid=False)
            sentences = Counter(
                " ".join(part.split())
                for part in re.split(r"(?<=[.!?])\s+", row["text"])
                if len(part) >= 40
            )
            result["maximum_raw_sentence_copies"] = max(sentences.values(), default=0)
            previous = baseline.get(row["id"])
            if previous:
                result["prompt_tokens_match_reference"] = (
                    row["prompt_token_ids"] == previous["prompt_token_ids"]
                )
                result["text_matches_reference"] = row["text"] == previous["text"]
                actual = row.get("output_token_ids", [])
                expected = previous.get("output_token_ids", [])
                result["matching_initial_output_tokens"] = next(
                    (i for i, (a, b) in enumerate(zip(actual, expected)) if a != b),
                    min(len(actual), len(expected)),
                )
            try:
                value = json.loads(row["text"])
                validator_for(case["schema"])(case["schema"]).validate(value)
                result["schema_valid"] = True
                if case["kind"] == "dictation":
                    raw_fields = {item["field_id"] for item in value}
                    result["raw_missing_fields"] = sorted(
                        set(expected_fields) - raw_fields
                    )
                    result["raw_unexpected_fields"] = sorted(
                        raw_fields - set(expected_fields)
                    )
                    result["raw_value"] = value
                    parsed = voice.validate(
                        USVoiceFormGeneration.model_validate(value), case["transcript"]
                    )
                    result["validated_value"] = parsed.model_dump(mode="json")
                    fields = {
                        p["fieldId"] for p in result["validated_value"]["proposals"]
                    }
                    result["missing_expected_fields"] = sorted(
                        set(expected_fields) - fields
                    )
                    result["unexpected_fields"] = sorted(fields - set(expected_fields))
                else:
                    result["remarks_characters"] = len(
                        value.get("descriptionRemarks") or ""
                    )
                    result["remarks"] = value.get("descriptionRemarks")
                    # complete() validates content directly; it does not select a runtime.
                    reports.complete(
                        row["text"],
                        USExaminationRequest.model_validate(case["body"]),
                        model_id=case["model"],
                        language_code=LanguageCode.RU,
                    )
                result["main_valid"] = True
            except Exception as error:
                result["validation_error"] = getattr(
                    error, "code", type(error).__name__
                )
            results.append(result)
    (args.directory / "validation.json").write_text(
        json.dumps(results, ensure_ascii=False, indent=2) + "\n"
    )
    for runtime in sorted({r["runtime"] for r in results}):
        rows = [r for r in results if r["runtime"] == runtime]
        print(
            json.dumps(
                {
                    "runtime": runtime,
                    "count": len(rows),
                    "finish": dict(Counter(r["finish"] for r in rows)),
                    "schema_valid": sum(r["schema_valid"] for r in rows),
                    "main_valid": sum(r["main_valid"] for r in rows),
                }
            )
        )


if __name__ == "__main__":
    main()
