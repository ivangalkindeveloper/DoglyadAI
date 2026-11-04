from __future__ import annotations

import asyncio
import json
from typing import Any
from uuid import UUID

import httpx
import pytest

from app.core.configuration.configuration import Configuration
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.configuration.variables import Variables
from app.core.localization.language_code import LanguageCode
from app.error import ApiError
from app.model.neural_model.neural_model_service_operation import NeuralModelServiceOperation
from app.model.neural_model.neural_model_service_request import NeuralModelServiceRequest
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)
from app.model.ultrasound.us_examination_scan_photo import USExaminationScanPhoto
from app.service.neural_model.inference_service import InferenceService

_URL = "http://10.0.0.11:8100/v1/generation"
_RESPONSE = '{"description":"Description","conclusion":"Conclusion","recommendations":"Recommendations"}'
_STRUCTURED_OUTPUT = '{"type":"object"}'
_MODEL = USExaminationNeuralModel(
    id="google/medgemma-4b-it",
    title="MedGemma 4B",
    entitlement="base",
    accessibility=USExaminationNeuralModelAccessibility.AVAILABLE,
    contextLength=128000,
    descriptionLocaleKey="googleMedGemma4BDescription",
)
_ENDPOINTS = {_MODEL.id: _URL}


def _request(
    model: USExaminationNeuralModel = _MODEL,
    photos: list[USExaminationScanPhoto] | None = None,
    token: str | None = "app-check-token",
    request_id: str | None = None,
    report_measurements: tuple[str, ...] = (),
    repetition_penalty: float | None = None,
) -> NeuralModelServiceRequest:
    return NeuralModelServiceRequest(
        operation=NeuralModelServiceOperation.GENERATE_REPORT,
        language_code=LanguageCode.EN,
        model_id=model.id,
        system_prompt="system",
        prompt="prompt",
        structured_output=_STRUCTURED_OUTPUT,
        temperature=0.3,
        max_tokens=512,
        repetition_penalty=repetition_penalty,
        photos=photos or [],
        app_check_token=token,
        request_id=request_id,
        report_measurements=report_measurements,
    )


def _call(
    handler: Any,
    request: NeuralModelServiceRequest | None = None,
) -> str:
    configuration = ConfigurationLoader(
        Variables(
            environment="development",
        ).configuration_directory,
    ).load()

    async def run() -> str:
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                handler,
            ),
        ) as client:
            return await InferenceService(
                client,
                _ENDPOINTS,
                configuration.server.inference,
            ).call(
                request or _request(),
            )

    return asyncio.run(
        run(),
    )


def test_app_check_token_is_relayed_to_the_gpu_vm() -> None:
    # The GPU VM verifies the token itself, so it has to arrive there unchanged.
    seen: dict[str, str] = {}

    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        seen.update(
            request.headers,
        )
        return httpx.Response(
            200,
            json={"modelId": _MODEL.id, "response": _RESPONSE},
        )

    _call(
        handler,
    )

    assert seen["x-firebase-appcheck"] == "app-check-token"


def test_request_id_is_relayed_to_the_gpu_vm() -> None:
    request_id = "a" * 32
    seen: dict[str, str] = {}

    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        seen.update(
            request.headers,
        )
        return httpx.Response(
            200,
            json={"modelId": _MODEL.id, "response": _RESPONSE},
        )

    _call(
        handler,
        _request(
            request_id=request_id,
        ),
    )

    assert seen["x-request-id"] == request_id


@pytest.mark.parametrize(
    "repetition_penalty",
    [None, 1.05],
)
def test_request_carries_prompts_images_schema_and_sampling(
    repetition_penalty: float | None,
) -> None:
    seen: dict[str, Any] = {}

    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        seen.update(
            json.loads(
                request.content,
            ),
        )
        return httpx.Response(
            200,
            json={"modelId": _MODEL.id, "response": _RESPONSE},
        )

    _call(
        handler,
        _request(
            photos=[
                USExaminationScanPhoto(
                    id=UUID(
                        int=1,
                    ),
                    data="QUJD",
                ),
                USExaminationScanPhoto(
                    id=UUID(
                        int=2,
                    ),
                    data="REVG",
                ),
            ],
            report_measurements=("2.7 mm", "180 ml"),
            repetition_penalty=repetition_penalty,
        ),
    )

    assert seen["modelId"] == _MODEL.id
    assert seen["systemPrompt"] == "system"
    assert seen["prompt"] == "prompt"
    assert seen["structuredOutput"] == _STRUCTURED_OUTPUT
    assert seen["images"] == [{"data": "QUJD"}, {"data": "REVG"}]
    assert seen["temperature"] == 0.3
    assert seen["maxTokens"] == 512
    expected = {"modelId", "systemPrompt", "prompt", "structuredOutput", "images", "temperature", "maxTokens"}
    if repetition_penalty is not None:
        expected.add(
            "repetitionPenalty",
        )
        assert seen["repetitionPenalty"] == repetition_penalty
    assert (
        set(
            seen,
        )
        == expected
    )


@pytest.mark.parametrize(
    "status_code",
    [401, 403],
)
def test_auth_status_is_preserved(
    status_code: int,
) -> None:
    # Preserve authentication failures rather than hiding them behind a generic
    # upstream error.
    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        return httpx.Response(
            status_code,
            json={"detail": "no"},
        )

    with pytest.raises(
        ApiError,
    ) as error:
        _call(
            handler,
        )

    assert error.value.status_code == status_code


def test_upstream_error_becomes_502() -> None:
    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        return httpx.Response(
            500,
            json={"detail": "boom"},
        )

    with pytest.raises(
        ApiError,
    ) as error:
        _call(
            handler,
        )

    assert error.value.status_code == 502


def test_unreachable_vm_becomes_502() -> None:
    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        raise httpx.ConnectError(
            "refused",
        )

    with pytest.raises(
        ApiError,
    ) as error:
        _call(
            handler,
        )

    assert error.value.status_code == 502


def test_blank_response_is_rejected() -> None:
    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        return httpx.Response(
            200,
            json={"modelId": _MODEL.id, "response": "   "},
        )

    with pytest.raises(
        ApiError,
    ) as error:
        _call(
            handler,
        )

    assert error.value.status_code == 502


def test_invalid_response_does_not_log_patient_data(
    caplog: pytest.LogCaptureFixture,
) -> None:
    patient_data = "Sensitive generated patient text"

    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        return httpx.Response(
            200,
            json={"modelId": _MODEL.id, "response": {"patient": patient_data}},
        )

    with pytest.raises(
        ApiError,
    ) as error:
        _call(
            handler,
        )

    assert error.value.status_code == 502
    assert (
        type(
            error.value.__cause__,
        ).__name__
        == "ValidationError"
    )
    assert patient_data not in caplog.text
    assert all(
        (record.exc_info is None for record in caplog.records),
    )


def test_response_from_another_model_is_rejected() -> None:
    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        return httpx.Response(
            200,
            json={"modelId": "google/another-model", "response": _RESPONSE},
        )

    with pytest.raises(
        ApiError,
    ) as error:
        _call(
            handler,
        )

    assert error.value.status_code == 502


def test_model_without_a_vm_is_not_sent_anywhere() -> None:
    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        raise AssertionError(
            "must not be called",
        )

    other = USExaminationNeuralModel(
        id="google/unsupported-model",
        title="Unsupported",
        entitlement="base",
        accessibility=USExaminationNeuralModelAccessibility.AVAILABLE,
        contextLength=128000,
        descriptionLocaleKey="unsupportedModelDescription",
    )

    with pytest.raises(
        ApiError,
    ) as error:
        _call(
            handler,
            _request(
                model=other,
            ),
        )

    assert error.value.status_code == 500


def test_operation_deadline_cancels_slow_transport(
    configuration: Configuration,
) -> None:
    async def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        await asyncio.sleep(
            1,
        )
        raise AssertionError(
            "The operation should have been cancelled",
        )

    async def run() -> None:
        config = configuration.server.inference.model_copy(
            update={"operation_timeout_seconds": 0.01},
        )
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                handler,
            ),
        ) as client:
            with pytest.raises(
                ApiError,
            ) as raised:
                await InferenceService(
                    client,
                    _ENDPOINTS,
                    config,
                ).call(
                    _request(),
                )
        assert raised.value.status_code == 504

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "status",
    [503, 504],
)
def test_busy_and_timeout_statuses_are_preserved(
    status: int,
) -> None:
    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        return httpx.Response(
            status,
            headers={"Retry-After": "7"},
        )

    with pytest.raises(
        ApiError,
    ) as raised:
        _call(
            handler,
        )
    assert raised.value.status_code == status
    if status == 503:
        assert raised.value.headers == {"Retry-After": "7"}
