"""Separate completion, schema validity, main validation and content observations."""

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

DIRECTORY = Path(__file__).resolve().parent
ROOT = DIRECTORY.parents[3]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=DIRECTORY)
    args = parser.parse_args()
    cases = {
        case["id"]: case
        for case in json.loads((args.directory / "cases.json").read_text())
    }
    configuration = ConfigurationLoader(ROOT / "backend/main/config/development").load()
    reports = ReportGenerationService(configuration, MockNeuralModelService())
    voice = VoiceFormValidator(configuration.voice_source_localization(LanguageCode.RU))
    results = []
    baselines = {}
    expected_fields = {
        "patient_name",
        "patient_complaints",
        "patient_height_cm",
        "patient_weight_kg",
    }
    for filename in (
        "vllm-xgrammar.jsonl",
        "vllm-guidance.jsonl",
        "transformers-xgrammar.jsonl",
    ):
        path = args.directory / filename
        if not path.exists():
            continue
        for line in path.read_text().splitlines():
            row = json.loads(line)
            if "id" not in row:
                continue
            case = cases[row["id"]]
            if path.stem == "vllm-xgrammar":
                baselines[row["id"]] = row
            result = {
                key: row[key]
                for key in ("id", "finish", "seconds", "usage")
                if key in row
            }
            result.update(runtime=path.stem, schema_valid=False, main_valid=False)
            baseline = baselines.get(row["id"])
            if baseline is not None and path.stem != "vllm-xgrammar":
                result["prompt_tokens_match_baseline"] = (
                    row["prompt_token_ids"] == baseline["prompt_token_ids"]
                )
                result["text_matches_baseline"] = row["text"] == baseline["text"]
                actual_tokens = row.get("output_token_ids", [])
                baseline_tokens = baseline.get("output_token_ids", [])
                result["matching_initial_output_tokens"] = next(
                    (
                        index
                        for index, (actual, expected) in enumerate(
                            zip(actual_tokens, baseline_tokens)
                        )
                        if actual != expected
                    ),
                    min(len(actual_tokens), len(baseline_tokens)),
                )
            if "error" in row:
                result["error"] = row["error"]
            sentences = Counter(
                " ".join(part.split())
                for part in re.split(r"(?<=[.!?])\s+", row["text"])
                if len(part) >= 40
            )
            # Includes cross-field copies. This diagnostic is not a clinical rejection rule.
            result["maximum_raw_sentence_copies"] = max(sentences.values(), default=0)
            try:
                value = json.loads(row["text"])
                validator_for(case["schema"])(case["schema"]).validate(value)
                result["schema_valid"] = True
                if case["kind"] == "dictation":
                    parsed = voice.validate(
                        USVoiceFormGeneration.model_validate(value), case["transcript"]
                    )
                    result["validated_value"] = parsed.model_dump(mode="json")
                    fields = {
                        p["fieldId"] for p in result["validated_value"]["proposals"]
                    }
                    result["missing_expected_fields"] = sorted(expected_fields - fields)
                    result["unexpected_fields"] = sorted(fields - expected_fields)
                else:
                    result["remarks_characters"] = len(
                        value.get("descriptionRemarks") or ""
                    )
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
            print(
                json.dumps(
                    {k: v for k, v in result.items() if k != "validated_value"},
                    ensure_ascii=False,
                )
            )
    (args.directory / "validation.json").write_text(
        json.dumps(results, ensure_ascii=False, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
