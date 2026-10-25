from __future__ import annotations

import asyncio
import base64
import json
from dataclasses import replace
from pathlib import Path
from unittest.mock import AsyncMock
from uuid import UUID

import httpx
import pytest
from fastapi import FastAPI, Request
from fastapi.testclient import TestClient

from app.core.api_error_handler import ApiErrorHandler
from app.core.configuration import Configuration
from app.core.create_app import create_app
from app.core.get_configuration_response_service import get_configuration_response_service
from app.core.get_report_generation_service import get_report_generation_service
from app.core.get_request_language import get_request_language
from app.core.language_code import LanguageCode
from app.core.request_body_limit_middleware import RequestBodyLimitMiddleware
from app.core.variables import Variables
from app.core.verify_app_check import verify_app_check
from app.error import ApiError
from app.service.configuration_response_service import ConfigurationResponseService
from app.service.image_request_validator import ImageRequestValidator
from app.service.neural_model_service import NeuralModelService
from app.service.report_generation_service import ReportGenerationService


@pytest.fixture
def body() -> dict[str, object]:
    return {
        "settingsAI": {},
        "examinationData": {
            "usExaminationTypeId": "bladder",
            "photos": [],
            "examinationNumber": "TEST-1",
            "patientName": "Test Patient",
            "patientGender": "female",
            "patientDateOfBirth": "1990-01-01T00:00:00Z",
            "patientComplaints": "No complaints",
            "examinationDescription": "Findings",
        },
        "isRecommendationsIncluded": False,
        "isPhotoRemarks": False,
        "isDescriptionRemarks": False,
    }


@pytest.mark.parametrize("field", ["examinationNumber", "patientName", "patientComplaints", "examinationDescription"])
def test_text_fields_at_configured_limit_with_six_photos_reach_model_without_truncation(
    app: FastAPI,
    configuration: Configuration,
    body: dict[str, object],
    field: str,
) -> None:
    maximum = getattr(configuration.modules.scan, field + "MaxLength")
    value = "x" * maximum
    examination = body["examinationData"]
    assert isinstance(examination, dict)
    examination[field] = value
    examination["photos"] = [
        {"id": str(UUID(int=index + 1)), "data": "QUJD"} for index in range(configuration.photo_max_count)
    ]
    model = AsyncMock(spec=NeuralModelService)
    model.call.return_value = '{"description":"Findings","conclusion":"Conclusion"}'
    service = ReportGenerationService(configuration, model)
    app.dependency_overrides[verify_app_check] = lambda: None
    app.dependency_overrides[get_report_generation_service] = lambda: service
    client = TestClient(app)
    try:
        response = client.post("/v1/ultrasound/generate_report", json=body)
    finally:
        client.close()
    assert response.status_code == 200, response.text
    generation = model.call.call_args.args[0]
    assert value in generation.prompt
    assert len(generation.photos) == configuration.photo_max_count


def test_photo_count_comes_from_loaded_application_config(
    configuration: Configuration,
    body: dict[str, object],
) -> None:
    from app.model.ultrasound.us_examination_request import USExaminationRequest

    application = {
        **configuration.application,
        "ultrasound": {**configuration.application["ultrasound"], "scanPhotoMaxNumber": 2},
    }
    configured = replace(configuration, application=application)
    examination = body["examinationData"]
    assert isinstance(examination, dict)
    examination["photos"] = [{"id": str(UUID(int=index + 1)), "data": "QUJD"} for index in range(3)]
    model = AsyncMock(spec=NeuralModelService)
    with pytest.raises(ApiError) as raised:
        asyncio.run(
            ReportGenerationService(configured, model).generate(
                USExaminationRequest.model_validate(body), language_code=LanguageCode.EN
            )
        )
    assert raised.value.status_code == 422
    model.call.assert_not_called()


@pytest.mark.parametrize("data,status", [("!!!", 422), ("", 422), ("YWJjZA==", 413)])
def test_invalid_or_oversized_images_are_rejected(data: str, status: int) -> None:
    with pytest.raises(ApiError) as raised:
        ImageRequestValidator(max_image_bytes=3, max_images=6).validate([data])
    assert raised.value.status_code == status


def test_image_at_exact_decoded_limit_is_accepted() -> None:
    ImageRequestValidator(max_image_bytes=3, max_images=6).validate([base64.b64encode(b"abc").decode()])


@pytest.mark.parametrize("mode", ["content-length", "chunked", "incorrect-content-length"])
def test_body_limit_checks_actual_bytes_before_json_parsing(mode: str) -> None:
    application = FastAPI()
    calls: list[bytes] = []

    @application.post("/body")
    async def endpoint(request: Request) -> dict[str, object]:
        calls.append(await request.body())
        return await request.json()

    application.add_middleware(
        RequestBodyLimitMiddleware, limits={"/body": 8}, default_limit=8, error_handler=ApiErrorHandler()
    )

    async def run() -> httpx.Response:
        async def chunks():
            yield b"not-json"
            yield b"more"

        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=application), base_url="http://test") as client:
            if mode == "chunked":
                return await client.post("/body", content=chunks())
            headers = {"Content-Length": "1"} if mode == "incorrect-content-length" else {}
            return await client.post("/body", content=b"not-json-more", headers=headers)

    assert asyncio.run(run()).status_code == 413
    assert calls == []


def test_body_at_exact_limit_is_delivered_unchanged() -> None:
    application = FastAPI()

    @application.post("/body")
    async def endpoint(request: Request) -> dict[str, object]:
        return await request.json()

    payload = json.dumps({"text": "Unicode: \u0410\u0411\u0412"}, ensure_ascii=False).encode()
    application.add_middleware(
        RequestBodyLimitMiddleware, limits={"/body": len(payload)}, default_limit=8, error_handler=ApiErrorHandler()
    )
    client = TestClient(application)
    try:
        response = client.post("/body", content=payload)
    finally:
        client.close()
    assert response.status_code == 200
    assert response.json() == json.loads(payload)


def test_endpoint_rate_is_loaded_from_json_and_counters_are_per_application(
    configuration: Configuration,
    tmp_path: Path,
) -> None:
    directory = tmp_path / "development"
    directory.mkdir()
    server = configuration.server.model_dump()
    server["endpoints"]["/v1/application_config"]["requests_per_minute"] = 1
    (directory / "server.json").write_text(json.dumps(server))
    clients = []
    for _ in range(2):
        application = create_app(Variables(environment="development", config_dir=tmp_path))
        application.dependency_overrides[verify_app_check] = lambda: None
        application.dependency_overrides[get_configuration_response_service] = lambda: ConfigurationResponseService(
            configuration
        )
        application.dependency_overrides[get_request_language] = lambda: LanguageCode.EN
        clients.append(TestClient(application))
    try:
        assert clients[0].get("/v1/application_config").status_code == 200
        response = clients[0].get("/v1/application_config")
        assert response.status_code == 429
        assert response.headers["Retry-After"] == "60"
        assert clients[1].get("/v1/application_config").status_code == 200
    finally:
        for client in clients:
            client.close()
