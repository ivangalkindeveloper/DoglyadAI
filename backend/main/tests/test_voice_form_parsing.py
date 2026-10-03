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
        {
            "proposals": [
                {"fieldId": "patientName", "value": "Иванов Иван", "sourceQuote": "Пациент Иванов Иван"},
                {"fieldId": "patientWeightKG", "value": "72", "sourceQuote": "Вес семьдесят два килограмма"},
                {"fieldId": "patientHeightCM", "value": "180", "sourceQuote": "рост сто восемьдесят"},
            ],
            "unmappedFindings": ["Вес семьдесят два килограмма", "несуществующая фраза"],
        }
    )

    response = validate_voice_form_generation(generated, transcript)

    assert [item.fieldId.value for item in response.proposals] == ["patientName", "patientWeightKG"]
    assert [item.value for item in response.proposals] == ["Иванов Иван", "72"]
    assert [item.value for item in response.rejectedFieldIds] == ["patientHeightCM"]
    assert response.unmappedFindings == ["Вес семьдесят два килограмма"]


def test_validator_rejects_duplicate_field_without_choosing_one() -> None:
    generated = USVoiceFormGeneration.model_validate(
        {
            "proposals": [
                {"fieldId": "patientGender", "value": "male", "sourceQuote": "male"},
                {"fieldId": "patientGender", "value": "female", "sourceQuote": "female"},
            ],
            "unmappedFindings": [],
        }
    )
    response = validate_voice_form_generation(generated, "male or female")
    assert response.proposals == []
    assert [item.value for item in response.rejectedFieldIds] == ["patientGender"]


class FakeModelService:
    def __init__(self, response: dict[str, Any]) -> None:
        self.response = response
        self.request: InferenceRequest | None = None

    async def call(self, request: InferenceRequest) -> str:
        self.request = request
        return json.dumps(self.response, ensure_ascii=False)


@pytest.mark.parametrize("language,expected_fragment", [("en_US", "Extract only"), ("ru_RU", "Извлеки только")])
def test_route_sends_text_only_to_gpu_and_returns_checked_proposals(language: str, expected_fragment: str) -> None:
    load_configs()
    service = FakeModelService(
        {
            "proposals": [
                {"fieldId": "patientWeightKG", "value": "72", "sourceQuote": "вес 72 килограмма"},
            ],
            "unmappedFindings": [],
        }
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

    assert response.proposals[0].value == "72"
    assert service.request is not None
    assert service.request.model_id == "google/medgemma-4b-it"
    assert service.request.max_tokens == 2048
    assert service.request.photos == []
    assert service.request.app_check_token == "token"
    assert service.request.request_id == "b" * 32
    assert json.loads(service.request.prompt)["transcript"] == body.transcript
    assert json.loads(service.request.structured_output)["properties"]["proposals"]
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
