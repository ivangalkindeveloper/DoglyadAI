"""Freeze paired JSON-format changes and actual updated main-backend requests."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import sys

from jsonschema import Draft202012Validator

DIRECTORY = Path(__file__).resolve().parent
ROOT = DIRECTORY.parents[3]
sys.path.insert(0, str(ROOT / "backend/main"))
from app.core.configuration.configuration_loader import ConfigurationLoader  # noqa: E402
from app.core.localization.language_code import LanguageCode  # noqa: E402
from app.model.ultrasound.us_examination_request import USExaminationRequest  # noqa: E402
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService  # noqa: E402
from app.service.report.report_generation_service import ReportGenerationService  # noqa: E402


def main() -> None:
    config = ConfigurationLoader(ROOT / "backend/main/config/development").load()
    service = ReportGenerationService(config, MockNeuralModelService())
    baseline = json.loads((DIRECTORY / "source-cases.json").read_text())
    variants: dict[str, list[dict]] = {
        x: [] for x in ("baseline", "prompt-only", "bounded", "working")
    }
    for original in baseline:
        greedy = "greedy" in original["id"]
        if greedy:
            variants["baseline"].append(copy.deepcopy(original))
            prompt = copy.deepcopy(original)
            if prompt["kind"] != "dictation":
                prompt["payload"]["messages"][0]["content"] += config.text(
                    LanguageCode.RU, "reportStructuredOutputPrompt"
                ).format(
                    schema=json.dumps(
                        prompt["schema"], ensure_ascii=False, separators=(",", ":")
                    )
                )
            variants["prompt-only"].append(prompt)
        changed = copy.deepcopy(original)
        if original["kind"] != "dictation":
            body = USExaminationRequest.model_validate(original["body"])
            prepared = service.prepare(body, language_code=LanguageCode.RU)
            schema = json.loads(prepared.structured_output)
            Draft202012Validator.check_schema(schema)
            changed["schema"] = schema
            changed["payload"]["response_format"]["json_schema"]["schema"] = schema
            changed["payload"]["messages"][0]["content"] += config.text(
                LanguageCode.RU, "reportStructuredOutputPrompt"
            ).format(schema=prepared.structured_output)
            if original["kind"] in {"report", "conflict"}:
                working = copy.deepcopy(changed)
                working["payload"]["messages"] = [
                    {"role": "system", "content": prepared.system_prompt},
                    {"role": "user", "content": prepared.prompt},
                ]
                working["payload"]["repetition_penalty"] = prepared.repetition_penalty
                working["actual_main_request"] = True
                variants["working"].append(working)
        variants["bounded"].append(changed)
    for name, cases in variants.items():
        (DIRECTORY / f"{name}-cases.json").write_text(
            json.dumps(cases, ensure_ascii=False, indent=2) + "\n"
        )
        print(name, len(cases))


if __name__ == "__main__":
    main()
