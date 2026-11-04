"""Distinguish complete JSON, repeated content, and forced length boundaries."""

from __future__ import annotations

from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import statistics
import sys

from jsonschema.validators import validator_for

DIRECTORY = Path(__file__).resolve().parent
ROOT = DIRECTORY.parents[3]
sys.path.insert(0, str(ROOT / "backend/main"))
from app.core.configuration.configuration_loader import ConfigurationLoader  # noqa: E402
from app.core.localization.language_code import LanguageCode  # noqa: E402
from app.model.ultrasound.us_examination_request import USExaminationRequest  # noqa: E402
from app.model.ultrasound.us_report_preview_response import USReportPreviewResponse  # noqa: E402
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration  # noqa: E402
from app.service.dictation.voice_form_validator import VoiceFormValidator  # noqa: E402
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService  # noqa: E402
from app.service.report.report_generation_service import ReportGenerationService  # noqa: E402
from app.service.report.report_validator import ReportValidator  # noqa: E402


def sections(text: str, schema: dict) -> dict:
    """Partial parsing exposes loops even if the final JSON never closes."""
    preview = USReportPreviewResponse.parse_partial(text)
    result = {}
    for field, value in preview.model_dump().items():
        if value is None:
            continue
        field_schema = schema.get("properties", {}).get(field, {})
        maximum = next(
            (
                variant["maxLength"]
                for variant in field_schema.get("anyOf", [field_schema])
                if "maxLength" in variant
            ),
            None,
        )
        sentences = Counter(
            normalized
            for sentence in re.split(r"(?<=[.!?])\s+", value)
            if len(normalized := " ".join(sentence.split())) >= 40
            and normalized.endswith((".", "!", "?"))
        )
        try:
            ReportValidator.validate_repetition(
                USReportPreviewResponse.model_validate({field: value})
            )
            rejected = False
        except Exception:
            rejected = True
        result[field] = {
            "characters": len(value),
            "max_length": maximum,
            "at_max_length": maximum is not None and len(value) == maximum,
            "over_max_length": maximum is not None and len(value) > maximum,
            "maximum_sentence_copies": max(sentences.values(), default=0),
            "repeated_sentences": {k: v for k, v in sentences.items() if v >= 3},
            "production_repetition_rejected": rejected,
            "ends_in_sentence_punctuation": value.rstrip().endswith((".", "!", "?")),
            "tail": value[-160:],
        }
    return result


def main() -> None:
    config = ConfigurationLoader(ROOT / "backend/main/config/development").load()
    service = ReportGenerationService(config, MockNeuralModelService())
    voice = VoiceFormValidator(config.voice_source_localization(LanguageCode.RU))
    summary = {}
    source_files = [
        "app/schema/us_examination_report_structured_output.py",
        "app/prompt/prompt_factory.py",
        "app/service/report/report_generation_service.py",
        "app/service/report/report_validator.py",
        "app/model/ultrasound/us_report_generation_config.py",
        "app/core/localization/prompt_localization_validator.py",
        "config/development/server.json",
        "config/development/ru/l10n.json",
    ]
    (DIRECTORY / "validation-source.json").write_text(
        json.dumps(
            {
                name: hashlib.sha256((ROOT / "backend/main" / name).read_bytes()).hexdigest()
                for name in source_files
            },
            indent=2,
        ) + "\n"
    )
    for variant in ("baseline", "prompt-only", "bounded", "working", "unbounded-grammar"):
        if not (DIRECTORY / f"{variant}-cases.json").exists():
            continue
        cases = {
            case["id"]: case
            for case in json.loads((DIRECTORY / f"{variant}-cases.json").read_text())
        }
        path = DIRECTORY / f"{variant}-results.jsonl"
        if not path.exists():
            summary[variant] = {"expected": len(cases), "received": 0, "complete": False}
            continue
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        validated = []
        for row in rows:
            if row.get("phase") != "quality":
                continue
            case = cases[row["id"]]
            result = {
                key: row.get(key)
                for key in ("id", "kind", "finish", "done", "seconds", "first_delta_seconds", "usage", "error")
            }
            result.update(json_valid=False, schema_valid=False, main_valid=False)
            if case["kind"] != "dictation":
                result["sections"] = sections(row["text"], case["schema"])
            try:
                value = json.loads(row["text"])
                result["json_valid"] = True
                result["description_equals_conclusion"] = (
                    isinstance(value, dict)
                    and bool(value.get("description"))
                    and value.get("description") == value.get("conclusion")
                )
                validator_for(case["schema"])(case["schema"]).validate(value)
                result["schema_valid"] = True
                if case["kind"] == "dictation":
                    voice.validate(USVoiceFormGeneration.model_validate(value), case["transcript"])
                else:
                    service.complete(
                        row["text"],
                        USExaminationRequest.model_validate(case["body"]),
                        model_id=case["model"],
                        language_code=LanguageCode.RU,
                    )
                result["main_valid"] = True
            except Exception as error:
                result["validation_error"] = getattr(error, "code", type(error).__name__)
            result["repetition_detected"] = any(
                section["maximum_sentence_copies"] >= 3
                or section["production_repetition_rejected"]
                for section in result.get("sections", {}).values()
            )
            result["fields_at_max_length"] = [
                field for field, section in result.get("sections", {}).items()
                if section["at_max_length"]
            ]
            result["review_candidate"] = (
                result["schema_valid"] and result["main_valid"]
                and result["finish"] == "stop" and result["done"]
                and not result["error"] and not result["repetition_detected"]
                and not result["fields_at_max_length"]
            )
            validated.append(result)
        identifiers = [r["id"] for r in validated]
        if len(identifiers) != len(set(identifiers)):
            raise ValueError(f"Duplicate case IDs in {path}")
        (DIRECTORY / f"{variant}-validation.json").write_text(
            json.dumps(validated, ensure_ascii=False, indent=2) + "\n"
        )
        summary[variant] = {
            "expected": len(cases),
            "received": len(validated),
            "complete": set(identifiers) == set(cases),
            "finish": dict(Counter(r["finish"] for r in validated)),
            "json_valid": sum(r["json_valid"] for r in validated),
            "schema_valid": sum(r["schema_valid"] for r in validated),
            "main_valid": sum(r["main_valid"] for r in validated),
            "repetition_detected": sum(r["repetition_detected"] for r in validated),
            "loop_to_token_limit": sum(r["repetition_detected"] and r["finish"] == "length" for r in validated),
            "at_character_limit": sum(bool(r["fields_at_max_length"]) for r in validated),
            "review_candidates": sum(r["review_candidate"] for r in validated),
            "description_equals_conclusion": sum(r.get("description_equals_conclusion", False) for r in validated),
            "median_seconds": statistics.median(r["seconds"] for r in validated) if validated else None,
            "scope": "Synthetic text cases only; validators do not prove clinical correctness.",
        }
    (DIRECTORY / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
