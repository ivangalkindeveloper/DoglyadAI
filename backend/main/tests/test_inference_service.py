from __future__ import annotations

import asyncio
import json
from typing import Any

import httpx
import pytest
from fastapi import HTTPException

from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)
from app.model.ultrasound.us_examination_scan_photo import USExaminationScanPhoto
from app.service.base import InferenceRequest
from app.service.inference import InferenceService

_URL = "http://10.0.0.11:8100/v1/generation"
_RESPONSE = '{"description":"Description","conclusion":"Conclusion","recommendations":"Recommendations"}'
_STRUCTURED_OUTPUT = '{"type":"object"}'
_MODEL = USExaminationNeuralModel(
    id="google/medgemma-4b-it",
    title="MedGemma 4B",
    accessibility=USExaminationNeuralModelAccessibility.AVAILABLE,
    description={"en": ""},
)
_ENDPOINTS = {_MODEL.id: _URL}


def _request(
    model: USExaminationNeuralModel = _MODEL,
    photos: list[USExaminationScanPhoto] | None = None,
    token: str | None = "app-check-token",
) -> InferenceRequest:
    return InferenceRequest(
        neural_model=model,
        settings=NeuralModelSettings(temperature=0.3, maxTokens=512),
        language_code="ru",
        system_prompt="system",
        prompt="prompt",
        structured_output=_STRUCTURED_OUTPUT,
        photos=photos or [],
        app_check_token=token,
    )


def _call(handler: Any, request: InferenceRequest | None = None) -> str:
    async def run() -> str:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            return await InferenceService(client, _ENDPOINTS).call(request or _request())

    return asyncio.run(run())


def test_app_check_token_is_relayed_to_the_gpu_vm() -> None:
    # The GPU VM verifies the token itself, so it has to arrive there unchanged.
    seen: dict[str, str] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen.update(request.headers)
        return httpx.Response(200, json={"modelId": _MODEL.id, "response": _RESPONSE})

    _call(handler)

    assert seen["x-firebase-appcheck"] == "app-check-token"


def test_request_carries_prompts_images_schema_and_sampling() -> None:
    seen: dict[str, Any] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen.update(json.loads(request.content))
        return httpx.Response(200, json={"modelId": _MODEL.id, "response": _RESPONSE})

    _call(handler, _request(photos=[USExaminationScanPhoto(data="QUJD"), USExaminationScanPhoto(data="REVG")]))

    assert seen["modelId"] == _MODEL.id
    assert seen["systemPrompt"] == "system"
    assert seen["prompt"] == "prompt"
    assert seen["structuredOutput"] == _STRUCTURED_OUTPUT
    assert seen["images"] == [{"data": "QUJD"}, {"data": "REVG"}]
    assert seen["temperature"] == 0.3
    assert seen["maxTokens"] == 512


@pytest.mark.parametrize("status_code", [401, 403])
def test_auth_status_is_preserved(status_code: int) -> None:
    # Preserve authentication failures rather than hiding them behind a generic
    # upstream error.
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(status_code, json={"detail": "no"})

    with pytest.raises(HTTPException) as error:
        _call(handler)

    assert error.value.status_code == status_code


def test_upstream_error_becomes_502() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500, json={"detail": "boom"})

    with pytest.raises(HTTPException) as error:
        _call(handler)

    assert error.value.status_code == 502


def test_unreachable_vm_becomes_502() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("refused")

    with pytest.raises(HTTPException) as error:
        _call(handler)

    assert error.value.status_code == 502


def test_blank_response_is_rejected() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"modelId": _MODEL.id, "response": "   "})

    with pytest.raises(HTTPException) as error:
        _call(handler)

    assert error.value.status_code == 502


def test_model_without_a_vm_is_not_sent_anywhere() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("must not be called")

    other = USExaminationNeuralModel(
        id="google/unsupported-model",
        title="Unsupported",
        accessibility=USExaminationNeuralModelAccessibility.AVAILABLE,
        description={"en": ""},
    )

    with pytest.raises(HTTPException) as error:
        _call(handler, _request(model=other))

    assert error.value.status_code == 500
