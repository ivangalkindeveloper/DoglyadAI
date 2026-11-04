"""Build synthetic report and dictation requests from current main configuration."""

from __future__ import annotations

import base64
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "backend/main"))
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.localization.language_code import LanguageCode
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.prompt.prompt_factory import PromptFactory
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService
from app.service.report.report_generation_service import ReportGenerationService

ROOT = Path(__file__).resolve().parents[3]
DIRECTORY = Path(__file__).parent


def main() -> None:
    configuration = ConfigurationLoader(ROOT / "backend/main/config/development").load()
    factory = PromptFactory(LanguageCode.RU, configuration)
    service = ReportGenerationService(configuration, MockNeuralModelService())
    body = json.loads((DIRECTORY / "ablation.json").read_text())["body"]
    cases = []
    for method in ("generate", "stream"):
        cases.append(
            {
                "name": "forced-whitespace-" + method,
                "method": method,
                "min_tokens": 512,
                "request": {
                    "modelId": "google/medgemma-4b-it",
                    "prompt": 'Return the JSON object {"ok":true}.',
                    "structuredOutput": json.dumps(
                        {
                            "type": "object",
                            "properties": {"ok": {"const": True}},
                            "required": ["ok"],
                            "additionalProperties": False,
                        }
                    ),
                    "temperature": 0,
                    "maxTokens": 1024,
                    "repetitionPenalty": 1.0,
                },
            }
        )
    for model in (
        "google/medgemma-4b-it",
        "google/medgemma-1.5-4b-it",
        "google/medgemma-27b-it",
    ):
        body["settingsAI"]["selectedNeuralModelId"] = model
        prepared = service.prepare(
            USExaminationRequest.model_validate(body), language_code=LanguageCode.RU
        )
        cases.append(
            {
                "name": "report-" + model.split("/")[-1],
                "method": "stream",
                "body": json.loads(json.dumps(body)),
                "request": {
                    "modelId": model,
                    "systemPrompt": prepared.system_prompt,
                    "prompt": prepared.prompt,
                    "structuredOutput": prepared.structured_output,
                    "temperature": prepared.temperature,
                    "maxTokens": prepared.max_tokens,
                    "repetitionPenalty": 1.0,
                },
            }
        )
        transcript = "Пациент Иванов Иван Иванович. Рост 180 сантиметров. Вес 80 килограммов. Жалобы на дискомфорт в области шеи."
        cases.append(
            {
                "name": "dictation-" + model.split("/")[-1],
                "method": "generate",
                "transcript": transcript,
                "request": {
                    "modelId": model,
                    "systemPrompt": factory.voice_system_prompt(),
                    "prompt": factory.voice_prompt(
                        configuration.resolve_examination_title(
                            "thyroidGland", LanguageCode.RU
                        ),
                        transcript,
                        configuration.resolve_examination_contextual_strings(
                            "thyroidGland", LanguageCode.RU
                        ),
                    ),
                    "structuredOutput": USVoiceFormGeneration.structured_output(),
                    "temperature": 0,
                    "maxTokens": configuration.server.voice_form_parsing.maxTokens,
                },
            }
        )
    schemas = {
        case["name"]: json.loads(case["request"]["structuredOutput"]) for case in cases
    }
    remote = (
        "import json,base64,xgrammar as xgr\ns=json.loads(base64.b64decode("
        + repr(base64.b64encode(json.dumps(schemas).encode()).decode())
        + "))\nprint(json.dumps({k:str(xgr.Grammar.from_json_schema(v,any_whitespace=True)) for k,v in s.items()}))"
    )
    response = subprocess.run(
        [
            "ssh",
            "-i",
            str(Path.home() / ".ssh/doglyad-inference"),
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=5",
            "ivangalkindeveloper@192.168.0.29",
            "docker",
            "exec",
            "-i",
            "doglyad-dgx-vllm_medgemma_4b-1",
            "python3",
            "-",
        ],
        input=remote,
        text=True,
        capture_output=True,
        check=True,
    )
    grammars = json.loads(response.stdout)
    for case in cases:
        case["grammar"] = grammars[case["name"]]
    (DIRECTORY / "completion-cases.json").write_text(
        json.dumps(cases, ensure_ascii=False, indent=2) + "\n"
    )
    print("Prepared", len(cases), "synthetic requests; no deployed service changed")


if __name__ == "__main__":
    main()
