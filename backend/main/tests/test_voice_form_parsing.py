from __future__ import annotations

# ruff: noqa: RUF001
import asyncio
import inspect
import json
from types import SimpleNamespace
from typing import Any

import pytest
from fastapi import HTTPException
from starlette.requests import Request

from app.core.config import load_configs
from app.model.inference.inference_request import InferenceRequest
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.model.ultrasound.us_voice_form_parse_request import USVoiceFormParseRequest
from app.route.ultrasound import parse_dictation as route
from app.service.voice_form_validation import validate_voice_form_generation


def test_voice_parsing_config_loads_for_both_environments() -> None:
    from app.core.config import _CONFIG_BASE, get_voice_parsing_config
    from app.model.ultrasound.us_voice_form_parsing_config import USVoiceFormParsingConfig

    for environment in ("development", "production"):
        config = USVoiceFormParsingConfig.model_validate_json(
            (_CONFIG_BASE / environment / "voice_form_parsing.json").read_text(encoding="utf-8")
        )
        assert config.modelId == "google/medgemma-4b-it"
    load_configs()
    assert get_voice_parsing_config().maxTokens == 2048


def test_validator_returns_sparse_supported_fields_and_rejects_bad_quotes() -> None:
    transcript = "Пациент Иванов Иван. Вес семьдесят два килограмма."
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_name", "value": "Иванов Иван", "evidence": "Пациент Иванов Иван", "accuracy": "full"},
            {
                "field_id": "patient_weight_kg",
                "value": 72,
                "evidence": "Вес семьдесят два килограмма",
                "accuracy": "full",
            },
            {"field_id": "patient_height_cm", "value": 180, "evidence": "рост сто восемьдесят", "accuracy": "full"},
        ]
    )

    response = validate_voice_form_generation(generated, transcript)

    assert [item.field_id.value for item in response.proposals] == ["patient_name", "patient_weight_kg"]
    assert [item.value for item in response.proposals] == ["Иванов Иван", 72]
    assert [item.value for item in response.rejectedFieldIds] == ["patient_height_cm"]
    assert response.unmappedFindings == []


def test_validator_rejects_duplicate_field_without_choosing_one() -> None:
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_gender", "value": "male", "evidence": "male", "accuracy": "full"},
            {"field_id": "patient_gender", "value": "female", "evidence": "female", "accuracy": "full"},
        ]
    )
    response = validate_voice_form_generation(generated, "male or female")
    assert response.proposals == []
    assert [item.value for item in response.rejectedFieldIds] == ["patient_gender"]


def test_empty_generation_leaves_form_unchanged() -> None:
    response = validate_voice_form_generation(USVoiceFormGeneration.model_validate([]), "Никаких данных формы")
    assert response.proposals == []
    assert response.rejectedFieldIds == []


def test_questionable_accuracy_survives_validation() -> None:
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "patient_name", "value": "Иванов", "evidence": "пациент Иванов", "accuracy": "questionable"}]
    )
    response = validate_voice_form_generation(generated, "пациент Иванов")
    assert response.proposals[0].accuracy.value == "questionable"


def test_boolean_measurement_is_not_accepted_as_one() -> None:
    with pytest.raises(ValueError):
        USVoiceFormGeneration.model_validate(
            [{"field_id": "patient_weight_kg", "value": True, "evidence": "вес", "accuracy": "full"}]
        )


def test_generation_schema_caps_repeated_items() -> None:
    schema = USVoiceFormGeneration.model_json_schema()
    assert schema["type"] == "array"
    assert schema["maxItems"] == 8
    assert set(schema["$defs"]["USVoiceFieldProposal"]["required"]) == {"field_id", "value", "evidence", "accuracy"}


class FakeModelService:
    def __init__(self, response: Any) -> None:
        self.response = response
        self.request: InferenceRequest | None = None

    async def call(self, request: InferenceRequest) -> str:
        self.request = request
        return json.dumps(self.response, ensure_ascii=False)


@pytest.mark.parametrize("language,expected_fragment", [("en_US", "Extract only"), ("ru_RU", "Извлеки только")])
def test_route_sends_text_only_to_gpu_and_returns_checked_proposals(language: str, expected_fragment: str) -> None:
    load_configs()
    service = FakeModelService(
        [{"field_id": "patient_weight_kg", "value": 72, "evidence": "вес 72 килограмма", "accuracy": "full"}]
    )
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v1/ultrasound/parse_dictation",
            "headers": [
                (b"accept-language", language.encode()),
                (b"x-firebase-appcheck", b"token"),
            ],
            "app": SimpleNamespace(state=SimpleNamespace(model_service=service)),
            "state": {"request_id": "b" * 32},
        }
    )
    body = USVoiceFormParseRequest(
        usExaminationTypeId="echocardiography",
        transcript="вес 72 килограмма",
    )
    handler: Any = inspect.unwrap(route.parse_dictation)

    response = asyncio.run(handler(body=body, request=request))

    assert response.proposals[0].value == 72
    assert service.request is not None
    assert service.request.model_id == "google/medgemma-4b-it"
    assert service.request.max_tokens == 2048
    assert service.request.photos == []
    assert service.request.app_check_token == "token"
    assert service.request.request_id == "b" * 32
    assert json.loads(service.request.prompt)["transcript"] == body.transcript
    assert json.loads(service.request.structured_output)["type"] == "array"
    assert expected_fragment in service.request.system_prompt


def test_route_rejects_unknown_examination_type() -> None:
    load_configs()
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v1/ultrasound/parse_dictation",
            "headers": [],
            "app": SimpleNamespace(state=SimpleNamespace(model_service=FakeModelService({}))),
            "state": {"request_id": "c" * 32},
        }
    )
    handler: Any = inspect.unwrap(route.parse_dictation)
    with pytest.raises(HTTPException) as error:
        asyncio.run(
            handler(
                body=USVoiceFormParseRequest(usExaminationTypeId="unknown", transcript="hello"),
                request=request,
            )
        )
    assert error.value.status_code == 400
