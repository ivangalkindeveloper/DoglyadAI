"""Apply main's report/dictation validation to synthetic live reader results."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "backend/main"))
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.localization.language_code import LanguageCode
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.service.dictation.voice_form_validator import VoiceFormValidator
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService
from app.service.report.report_generation_service import ReportGenerationService

ROOT = Path(__file__).resolve().parents[3]
DIRECTORY = Path(__file__).parent


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", default="completion-live-results.jsonl")
    parser.add_argument("--output", default="completion-main-validation.json")
    args = parser.parse_args()
    configuration = ConfigurationLoader(ROOT / "backend/main/config/development").load()
    service = ReportGenerationService(configuration, MockNeuralModelService())
    voice = VoiceFormValidator(configuration.voice_source_localization(LanguageCode.RU))
    cases = {
        case["name"]: case
        for case in json.loads((DIRECTORY / "completion-cases.json").read_text())
    }
    results = []
    for line in (DIRECTORY / args.input).read_text().splitlines():
        record = json.loads(line)
        case = cases[record["name"]]
        result = {"name": record["name"], "reader_success": record["is_success"]}
        if record["is_success"]:
            try:
                if "body" in case:
                    value = service.complete(
                        record["text"],
                        USExaminationRequest.model_validate(case["body"]),
                        model_id=record["model"],
                        language_code=LanguageCode.RU,
                    )
                    result["validated_result"] = value.model_dump(mode="json")
                elif "transcript" in case:
                    value = voice.validate(
                        USVoiceFormGeneration.model_validate_json(record["text"]),
                        case["transcript"],
                    )
                    result["validated_result"] = value.model_dump(mode="json")
                else:
                    assert json.loads(record["text"]) == {"ok": True}
                result["main_validation"] = "passed"
            except Exception as error:
                result["main_validation"] = getattr(error, "code", type(error).__name__)
        results.append(result)
        print(
            json.dumps({k: v for k, v in result.items() if k != "validated_result"}),
            flush=True,
        )
    (DIRECTORY / args.output).write_text(
        json.dumps(results, ensure_ascii=False, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
