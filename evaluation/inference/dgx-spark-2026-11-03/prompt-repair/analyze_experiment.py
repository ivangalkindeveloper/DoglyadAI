"""Review natural completion without treating a character cap as a solution."""

from __future__ import annotations

from collections import Counter
from dataclasses import replace
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

from jsonschema.validators import validator_for

DIRECTORY = Path(__file__).resolve().parent
ROOT = DIRECTORY.parents[3]
sys.path.insert(0, str(ROOT / "backend/main"))
from app.core.configuration.configuration_loader import ConfigurationLoader  # noqa: E402
from app.core.localization.language_code import LanguageCode  # noqa: E402
from app.model.ultrasound.us_examination_request import USExaminationRequest  # noqa: E402
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService  # noqa: E402
from app.service.report.report_generation_service import ReportGenerationService  # noqa: E402


def main() -> None:
    spec = importlib.util.spec_from_file_location("schema_analysis", DIRECTORY.parent / "schema-revision/analyze_results.py")
    assert spec is not None and spec.loader is not None
    helpers = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helpers)
    config = ConfigurationLoader(ROOT / "backend/main/config/development").load()
    current = ReportGenerationService(config, MockNeuralModelService())
    # This only disables length rejection in offline analysis. It does not
    # change the request, the engine, or the repetition/content validators.
    caps = {name: 1_000_000 for name in type(config.server.report_generation).model_fields if name.startswith("max_") and name.endswith("_characters")}
    uncapped_config = replace(config, server=config.server.model_copy(update={
        "report_generation": config.server.report_generation.model_copy(update=caps),
    }))
    uncapped = ReportGenerationService(uncapped_config, MockNeuralModelService())
    summary = {}
    for path in sorted(DIRECTORY.glob("*-results.jsonl")):
        variant = path.name.removesuffix("-results.jsonl")
        cases = {row["id"]: row for row in json.loads((DIRECTORY / f"{variant}-cases.json").read_text())}
        checked = []
        for line in path.read_text().splitlines():
            row = json.loads(line)
            if row.get("phase") != "quality":
                continue
            case = cases[row["id"]]
            record = {key: row.get(key) for key in ("id", "kind", "finish", "done", "error", "seconds", "usage")}
            record["task"] = case.get("task", "report")
            is_report = record["task"] == "report"
            record.update(schema_valid=False, current_main_valid=False, uncapped_main_valid=False)
            raw_text = row["text"]
            if case.get("output_aliases"):
                try:
                    raw_text = json.dumps({case["output_aliases"].get(key, key): value for key, value in json.loads(raw_text).items()}, ensure_ascii=False)
                except ValueError:
                    pass
            record["sections"] = helpers.sections(raw_text, case["schema"])
            record["repetition"] = any(
                field["maximum_sentence_copies"] >= 3 or field["production_repetition_rejected"]
                for field in record["sections"].values()
            )
            try:
                value = json.loads(row["text"])
                validator_for(case["schema"])(case["schema"]).validate(value)
                record["schema_valid"] = True
                value = json.loads(raw_text)
                record["description_equals_conclusion"] = is_report and value.get("description") == value.get("conclusion")
                record["remarks_present"] = bool(value.get("descriptionRemarks"))
                body = USExaminationRequest.model_validate(case["body"])
                for name, service in ((("current", current), ("uncapped", uncapped)) if is_report else ()):
                    try:
                        service.complete(raw_text, body, model_id=case["model"], language_code=LanguageCode(case.get("language", "ru")))
                        record[f"{name}_main_valid"] = True
                    except Exception as error:
                        record[f"{name}_validation_error"] = getattr(error, "code", type(error).__name__)
            except Exception as error:
                record["schema_error"] = type(error).__name__
            record["review_candidate"] = bool(
                record["schema_valid"] and record["uncapped_main_valid"]
                and not record["repetition"] and record["finish"] == "stop"
                and record["done"] and not record["error"]
            )
            checked.append(record)
        identifiers = [row["id"] for row in checked]
        assert len(identifiers) == len(set(identifiers))
        summary[variant] = {
            "received": len(checked), "expected": len(cases), "complete": set(identifiers) == set(cases),
            "tasks": dict(Counter(row["task"] for row in checked)),
            "finish": dict(Counter(row["finish"] for row in checked)),
            "repetition": sum(row["repetition"] for row in checked),
            "schema_valid": sum(row["schema_valid"] for row in checked),
            "current_main_valid": sum(row["current_main_valid"] for row in checked),
            "uncapped_main_valid": sum(row["uncapped_main_valid"] for row in checked),
            "description_equals_conclusion": sum(row.get("description_equals_conclusion", False) for row in checked),
            "review_candidates": sum(row["review_candidate"] for row in checked),
        }
        (DIRECTORY / f"{variant}-validation.json").write_text(json.dumps(checked, ensure_ascii=False, indent=2) + "\n")
    (DIRECTORY / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    files = ["app/prompt/prompt_factory.py", "app/schema/us_examination_report_structured_output.py", "app/service/report/report_validator.py", "config/development/ru/l10n.json"]
    (DIRECTORY / "validation-source.json").write_text(json.dumps({name: hashlib.sha256((ROOT / "backend/main" / name).read_bytes()).hexdigest() for name in files}, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
