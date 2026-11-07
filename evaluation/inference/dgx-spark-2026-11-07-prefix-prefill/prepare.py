"""Prepare synthetic prefix experiments from the current application code.

Candidates change only text placement and the textual copy of the photo enum.
The response_format schema and patient/image input remain unchanged.
"""

from __future__ import annotations

import base64
import copy
import hashlib
import io
import json
from pathlib import Path
import sys
from uuid import NAMESPACE_URL, uuid5

from jsonschema.validators import validator_for
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
REPOSITORY = ROOT.parents[2]
sys.path.insert(0, str(REPOSITORY / "backend/main"))

from app.core.configuration.configuration_loader import ConfigurationLoader  # noqa: E402
from app.core.localization.language_code import LanguageCode  # noqa: E402
from app.model.ultrasound.us_examination_request import USExaminationRequest  # noqa: E402
from app.prompt.prompt_factory import PromptFactory  # noqa: E402
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService  # noqa: E402
from app.service.report.report_generation_service import ReportGenerationService  # noqa: E402

MODELS = {
    "4b": "google/medgemma-4b-it",
    "15-4b": "google/medgemma-1.5-4b-it",
    "27b": "google/medgemma-27b-it",
}
VARIANTS = ("baseline", "template_first", "stable_schema", "combined")


def save(name: str, value: object) -> None:
    (ROOT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def image_data(patient: int) -> str:
    # Artificial image tests the transport and identifiers, not ultrasound accuracy.
    image = Image.new("RGB", (256, 256), "black")
    draw = ImageDraw.Draw(image)
    draw.rectangle((40 + patient * 10, 50, 180, 200), fill=(80, 80, 80))
    output = io.BytesIO()
    image.save(output, format="JPEG")
    return base64.b64encode(output.getvalue()).decode()


def prefix_length(left: str, right: str) -> int:
    return next(
        (i for i, pair in enumerate(zip(left, right)) if pair[0] != pair[1]),
        min(len(left), len(right)),
    )


def texts(payload: dict) -> str:
    return "\n<user>\n".join(
        part["text"]
        for message in payload["messages"]
        for part in message["content"]
        if part["type"] == "text"
    )


def main() -> None:
    configurations = {
        environment: ConfigurationLoader(
            REPOSITORY / "backend/main/config" / environment
        ).load()
        for environment in ("development", "production")
    }
    previous = json.loads(
        (
            ROOT.with_name("dgx-spark-2026-11-05-ngram-capacity") / "cases-4b.json"
        ).read_text()
    )
    sources = {case["id"]: case for case in previous}
    cases, comparisons = [], []
    checks = {
        "schema_unchanged": 0,
        "patient_text_preserved": 0,
        "foreign_photo_id_rejected": 0,
        "environment_parity": 0,
    }
    for language, source_id, template_key in (
        (LanguageCode.RU, "report-greedy-0", "thyroidGlandStandardContent"),
        (LanguageCode.EN, "bladder-en-sample-42", "bladderNormalContent"),
    ):
        for is_photo in (False, True):
            for is_template in (False, True):
                scenario = (
                    f"{language.value}-photo{int(is_photo)}-template{int(is_template)}"
                )
                for model_key, model_id in MODELS.items():
                    pairs = {variant: [] for variant in VARIANTS}
                    for patient in (0, 1):
                        body = copy.deepcopy(sources[source_id]["body"])
                        body["settingsAI"].update(
                            selectedNeuralModelId=model_id,
                            temperature=0,
                            maxTokens=2048,
                        )
                        body["isPhotoRemarks"] = is_photo
                        body["examinationData"].update(
                            examinationNumber=f"PREFIX-SYNTHETIC-{patient}",
                            patientName=f"Synthetic patient {patient}",
                            patientDateOfBirth=f"198{patient}-01-15T00:00:00Z",
                            photos=[
                                {
                                    "id": str(
                                        uuid5(
                                            NAMESPACE_URL,
                                            f"doglyad-prefix:{scenario}:{patient}",
                                        )
                                    ),
                                    "data": image_data(patient),
                                }
                            ]
                            if is_photo
                            else [],
                        )
                        configuration = configurations["development"]
                        body["template"] = (
                            configuration.text(language, template_key)
                            if is_template
                            else None
                        )
                        request = USExaminationRequest.model_validate(body)
                        prepared = ReportGenerationService(
                            configuration, MockNeuralModelService()
                        ).prepare(request, language_code=language)
                        production = ReportGenerationService(
                            configurations["production"], MockNeuralModelService()
                        ).prepare(request, language_code=language)
                        assert (
                            prepared.system_prompt,
                            prepared.prompt,
                            prepared.structured_output,
                        ) == (
                            production.system_prompt,
                            production.prompt,
                            production.structured_output,
                        )
                        checks["environment_parity"] += 1
                        schema = json.loads(prepared.structured_output)
                        generic = copy.deepcopy(schema)
                        if is_photo:
                            enum_schema = schema["$defs"]["USExaminationPhotoRemarks"][
                                "properties"
                            ]["photoId"]
                            validator = validator_for(enum_schema)(enum_schema)
                            validator.validate(
                                body["examinationData"]["photos"][0]["id"]
                            )
                            assert not validator.is_valid(
                                "00000000-0000-0000-0000-000000000000"
                            )
                            checks["foreign_photo_id_rejected"] += 1
                            del generic["$defs"]["USExaminationPhotoRemarks"][
                                "properties"
                            ]["photoId"]["enum"]
                        generic_text = json.dumps(
                            generic, ensure_ascii=False, separators=(",", ":")
                        )
                        title = configuration.resolve_examination_title(
                            request.examinationData.usExaminationTypeId, language
                        )
                        without_template = PromptFactory(
                            language, configuration
                        ).build_prompt(request.examinationData, title, None)
                        template_section = (
                            configuration.text(language, "reportTemplatePrompt").format(
                                value=body["template"]
                            )
                            if is_template
                            else ""
                        )
                        if is_template:
                            assert prepared.prompt.count(template_section) == 1
                            assert (
                                prepared.prompt.replace(template_section, "", 1)
                                == without_template
                            )
                        for variant in VARIANTS:
                            system, prompt = prepared.system_prompt, prepared.prompt
                            if variant in ("stable_schema", "combined"):
                                assert system.count(prepared.structured_output) == 1
                                system = system.replace(
                                    prepared.structured_output, generic_text, 1
                                )
                            if variant in ("template_first", "combined"):
                                prompt = template_section + without_template
                            content = [{"type": "text", "text": prompt}] + [
                                {
                                    "type": "image_url",
                                    "image_url": {
                                        "url": "data:image/jpeg;base64," + photo["data"]
                                    },
                                }
                                for photo in body["examinationData"]["photos"]
                            ]
                            payload = {
                                "model": model_id,
                                "messages": [
                                    {
                                        "role": "system",
                                        "content": [{"type": "text", "text": system}],
                                    },
                                    {"role": "user", "content": content},
                                ],
                                "response_format": {
                                    "type": "json_schema",
                                    "json_schema": {
                                        "name": "structured_response",
                                        "schema": schema,
                                    },
                                },
                                "temperature": 0,
                                "max_tokens": prepared.max_tokens,
                                "repetition_penalty": prepared.repetition_penalty,
                            }
                            assert (
                                payload["response_format"]["json_schema"]["schema"]
                                == schema
                            )
                            assert (
                                prompt.replace(template_section, "", 1)
                                == without_template
                                if is_template
                                else prompt == without_template
                            )
                            assert all(
                                photo["id"] in prompt
                                for photo in body["examinationData"]["photos"]
                            )
                            checks["schema_unchanged"] += 1
                            checks["patient_text_preserved"] += 1
                            case_id = f"{model_key}:{scenario}:{variant}:{patient}"
                            cases.append(
                                {
                                    "id": case_id,
                                    "model_key": model_key,
                                    "scenario": scenario,
                                    "variant": variant,
                                    "patient": patient,
                                    "language": language.value,
                                    "body": body,
                                    "payload": payload,
                                    "is_synthetic_image": is_photo,
                                }
                            )
                            pairs[variant].append(texts(payload))
                    for variant, pair in pairs.items():
                        comparisons.append(
                            {
                                "model": model_key,
                                "scenario": scenario,
                                "variant": variant,
                                "common_prefix_characters": prefix_length(*pair),
                                "input_text_characters": [len(text) for text in pair],
                            }
                        )
    paths = [
        "backend/main/app/prompt/prompt_factory.py",
        "backend/main/app/schema/us_examination_report_structured_output.py",
        "backend/main/app/service/report/report_generation_service.py",
        "backend/inference/app/service/vllm_service.py",
        "deploy/inference/profiles/dgx-spark.json",
    ]
    save("cases.json", cases)
    save(
        "static-analysis.json",
        {
            "unit": "Unicode characters; not model tokens or measured cache hits",
            "cases": len(cases),
            "checks": checks,
            "comparisons": comparisons,
        },
    )
    save(
        "source-hashes.json",
        {
            path: hashlib.sha256((REPOSITORY / path).read_bytes()).hexdigest()
            for path in paths
        },
    )
    print(
        json.dumps(
            {
                "cases": len(cases),
                "checks": checks,
                "sample_ru_4b": [
                    row
                    for row in comparisons
                    if row["model"] == "4b" and row["scenario"].startswith("ru-")
                ],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
