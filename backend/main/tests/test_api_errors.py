from __future__ import annotations

import asyncio
import logging
from collections.abc import AsyncIterator
from types import SimpleNamespace
from unittest.mock import AsyncMock

import httpx
import pytest
from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.testclient import TestClient
from pydantic import ValidationError
from starlette.requests import Request
from starlette.types import Receive, Scope, Send

from app.core.app_check.app_check import AppCheck
from app.core.application.service_dependencies import ServiceDependencies
from app.core.http.api_error_handler import ApiErrorHandler
from app.core.http.api_error_middleware import ApiErrorMiddleware
from app.core.http.request_body_limit_middleware import RequestBodyLimitMiddleware
from app.error import (
    ApiError,
    ImageTooLargeError,
    InferenceBusyError,
    InferenceTimeoutError,
    InferenceUnavailableError,
    InvalidInferenceResponseError,
    MissingAppCheckTokenError,
)
from app.model.api_error_response import ApiErrorResponse

_PATH = "/v1/ultrasound/generate_report"
_BODY = {
    "settingsAI": {},
    "examinationData": {
        "usExaminationTypeId": "bladder",
        "photos": [],
        "examinationNumber": "TEST",
        "patientName": "Test Patient",
        "patientGender": "female",
        "patientDateOfBirth": "1990-01-01T00:00:00Z",
        "examinationDescription": "Findings",
    },
}
_VALIDATION_PATH = "/v1/ultrasound/parse_dictation"
_FIELD = "transcript"


def _install_failure(
    app: FastAPI,
    error: Exception,
) -> None:
    service = SimpleNamespace(
        generate=AsyncMock(
            side_effect=error,
        ),
    )
    app.dependency_overrides[AppCheck.verify] = lambda: None
    app.dependency_overrides[ServiceDependencies.report_generation] = lambda: service


@pytest.mark.parametrize(
    "error",
    [
        ImageTooLargeError(),
        InferenceBusyError(
            7,
        ),
        InferenceTimeoutError(),
        InferenceUnavailableError(),
        InvalidInferenceResponseError(),
        MissingAppCheckTokenError(),
    ],
)
def test_expected_errors_use_class_metadata_and_request_id(
    app: FastAPI,
    error: ApiError,
) -> None:
    _install_failure(
        app,
        error,
    )
    client = TestClient(
        app,
    )
    try:
        response = client.post(
            _PATH,
            json=_BODY,
        )
    finally:
        client.close()
    payload = ApiErrorResponse.model_validate(
        response.json(),
    )
    assert response.status_code == error.status_code
    assert payload.code == error.code
    assert payload.detail == error.description
    assert payload.requestId == response.headers["X-Request-ID"]
    assert set(
        response.json(),
    ) == {"code", "detail", "requestId"}
    if error.headers:
        for name, value in error.headers.items():
            assert response.headers[name] == value


def test_expected_error_logs_once_without_original_exception_text(
    app: FastAPI,
    caplog: pytest.LogCaptureFixture,
) -> None:
    secret = "Sensitive patient details in provider error"
    error = InferenceUnavailableError()
    error.__cause__ = httpx.ConnectError(
        secret,
    )
    _install_failure(
        app,
        error,
    )
    client = TestClient(
        app,
    )
    try:
        response = client.post(
            _PATH,
            json=_BODY,
        )
    finally:
        client.close()
    assert response.status_code == 502
    assert secret not in response.text
    assert secret not in caplog.text
    records = [record for record in caplog.records if record.name == "app.core.http.api_error_handler"]
    assert (
        len(
            records,
        )
        == 1
    )
    assert records[0].exc_info is None
    assert "ConnectError" in records[0].message


def test_unexpected_error_does_not_escape_to_server_or_expose_patient_data(
    app: FastAPI,
    caplog: pytest.LogCaptureFixture,
) -> None:
    secret = "Sensitive patient details in unexpected failure"
    _install_failure(
        app,
        RuntimeError(
            secret,
        ),
    )
    # The default client re-raises escaping application errors, like an ASGI server would.
    client = TestClient(
        app,
    )
    try:
        response = client.post(
            _PATH,
            json=_BODY,
        )
    finally:
        client.close()
    assert response.status_code == 500
    assert response.json()["code"] == "internalServerError"
    assert response.json()["requestId"] == response.headers["X-Request-ID"]
    assert secret not in response.text
    assert secret not in caplog.text
    records = [record for record in caplog.records if record.name == "app.core.http.api_error_handler"]
    assert (
        len(
            records,
        )
        == 1
    )
    assert records[0].levelno == logging.ERROR
    assert records[0].exc_info is None
    assert "RuntimeError" in records[0].message


def test_input_validation_preserves_fields_without_echoing_values(
    app: FastAPI,
) -> None:
    secret = "Sensitive patient details in request"
    body = {"usExaminationTypeId": "bladder", "transcript": {"patient": secret}, secret: secret}
    _install_failure(
        app,
        AssertionError(
            "Validation must run before generation",
        ),
    )
    client = TestClient(
        app,
    )
    try:
        response = client.post(
            _VALIDATION_PATH,
            json=body,
        )
    finally:
        client.close()
    assert response.status_code == 422
    payload = ApiErrorResponse.model_validate(
        response.json(),
    )
    assert payload.code == "invalidRequest"
    assert payload.requestId == response.headers["X-Request-ID"]
    assert payload.fields is not None
    assert any(
        (field.location == ["body", _FIELD] and field.code == "string_type" for field in payload.fields),
    )
    assert secret not in response.text
    assert "input" not in response.json()


def test_validation_messages_and_context_are_sanitized(
    caplog: pytest.LogCaptureFixture,
) -> None:
    secret = "Sensitive validation context"
    error = RequestValidationError(
        [
            {
                "type": "value_error",
                "loc": ("body", "patientName"),
                "msg": secret,
                "input": secret,
                "ctx": {
                    "error": ValueError(
                        secret,
                    )
                },
            },
            {
                "type": "extra_forbidden",
                "loc": ("body", secret),
                "msg": secret,
                "input": secret,
            },
        ],
    )
    request = Request(
        {"type": "http", "method": "POST", "path": "/", "headers": []},
    )
    response = asyncio.run(
        ApiErrorHandler().handle(
            request,
            error,
        ),
    )
    payload = ApiErrorResponse.model_validate_json(
        response.body,
    )
    assert payload.fields is not None
    assert payload.fields[0].location == ["body", "patientName"]
    assert payload.fields[1].location == ["body"]
    assert (
        secret
        not in bytes(
            response.body,
        ).decode()
    )
    assert secret not in caplog.text


def test_invalid_json_has_the_same_error_contract(
    app: FastAPI,
) -> None:
    app.dependency_overrides[AppCheck.verify] = lambda: None
    client = TestClient(
        app,
    )
    try:
        response = client.post(
            _PATH,
            content=b'{"private":"sensitive',
            headers={"Content-Type": "application/json"},
        )
    finally:
        client.close()
    assert response.status_code == 422
    payload = ApiErrorResponse.model_validate(
        response.json(),
    )
    assert payload.code == "invalidRequest"
    assert payload.fields is not None
    assert payload.fields[0].code == "json_invalid"
    assert "sensitive" not in response.text


def test_framework_404_and_405_use_the_error_contract(
    app: FastAPI,
) -> None:
    client = TestClient(
        app,
    )
    try:
        missing = client.get(
            "/not-an-endpoint",
        )
        wrong_method = client.get(
            _PATH,
        )
    finally:
        client.close()
    assert missing.status_code == 404
    assert missing.json()["code"] == "resourceNotFound"
    assert wrong_method.status_code == 405
    assert wrong_method.json()["code"] == "methodNotAllowed"
    assert "POST" in wrong_method.headers["Allow"]
    for response in (missing, wrong_method):
        assert response.json()["requestId"] == response.headers["X-Request-ID"]


@pytest.mark.parametrize(
    "is_chunked",
    [False, True],
)
def test_body_limit_middleware_uses_the_same_formatter(
    is_chunked: bool,
) -> None:
    async def inner(
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        raise AssertionError(
            "An oversized request must not reach the application",
        )

    app = RequestBodyLimitMiddleware(
        inner,
        limits={"/body": 3},
        default_limit=3,
        error_handler=ApiErrorHandler(),
    )

    async def run() -> httpx.Response:
        async def chunks() -> AsyncIterator[bytes]:
            yield b"priv"
            yield b"ate"

        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(
                app=app,
            ),
            base_url="http://test",
        ) as client:
            return await client.post(
                "/body",
                content=chunks() if is_chunked else b"private",
            )

    response = asyncio.run(
        run(),
    )
    assert response.status_code == 413
    assert response.json()["code"] == "requestBodyTooLarge"
    assert response.json()["requestId"] == response.headers["X-Request-ID"]
    assert "private" not in response.text


def test_failure_in_middleware_uses_safe_500_without_reraising(
    caplog: pytest.LogCaptureFixture,
) -> None:
    secret = "Sensitive middleware failure"

    async def inner(
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        raise RuntimeError(
            secret,
        )

    async def run() -> httpx.Response:
        app = ApiErrorMiddleware(
            inner,
            ApiErrorHandler(),
        )
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(
                app=app,
            ),
            base_url="http://test",
        ) as client:
            return await client.get(
                "/",
            )

    response = asyncio.run(
        run(),
    )
    assert response.status_code == 500
    assert response.json()["code"] == "internalServerError"
    assert response.json()["requestId"] == response.headers["X-Request-ID"]
    assert secret not in response.text
    assert secret not in caplog.text


def test_failure_after_response_does_not_send_a_second_response(
    caplog: pytest.LogCaptureFixture,
) -> None:
    secret = "Sensitive background failure"

    async def inner(
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        await send(
            {"type": "http.response.start", "status": 200, "headers": []},
        )
        await send(
            {"type": "http.response.body", "body": b"completed"},
        )
        raise RuntimeError(
            secret,
        )

    async def run() -> httpx.Response:
        app = ApiErrorMiddleware(
            inner,
            ApiErrorHandler(),
        )
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(
                app=app,
            ),
            base_url="http://test",
        ) as client:
            return await client.get(
                "/",
            )

    response = asyncio.run(
        run(),
    )
    assert response.status_code == 200
    assert response.text == "completed"
    assert "internalServerError" in caplog.text
    assert secret not in caplog.text


def test_cancellation_propagates_without_turning_into_http_500() -> None:
    async def inner(
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        raise asyncio.CancelledError()

    async def run() -> None:
        app = ApiErrorMiddleware(
            inner,
            ApiErrorHandler(),
        )
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(
                app=app,
            ),
            base_url="http://test",
        ) as client:
            with pytest.raises(
                asyncio.CancelledError,
            ):
                await client.get(
                    "/",
                )

    asyncio.run(
        run(),
    )


def test_openapi_describes_the_error_dto_for_all_error_responses(
    app: FastAPI,
) -> None:
    schema = app.openapi()
    properties = schema["components"]["schemas"]["ApiErrorResponse"]["properties"]
    assert set(
        properties,
    ) == {"code", "detail", "requestId", "fields"}
    for status in ("401", "413", "422", "500", "502", "503", "504"):
        response_schema = schema["paths"][_PATH]["post"]["responses"][status]["content"]["application/json"]["schema"]
        assert response_schema == {"$ref": "#/components/schemas/ApiErrorResponse"}


@pytest.mark.parametrize(
    "field",
    ["code", "detail", "requestId"],
)
def test_error_response_rejects_blank_required_strings(
    field: str,
) -> None:
    values = {"code": "imageTooLarge", "detail": "Image is too large", "requestId": "a" * 32}
    values[field] = " \n "
    with pytest.raises(
        ValidationError,
    ):
        ApiErrorResponse.model_validate(
            values,
        )


def test_invalid_app_check_token_has_safe_error_contract(
    app: FastAPI,
    caplog: pytest.LogCaptureFixture,
) -> None:
    from unittest.mock import patch

    secret = "Sensitive data in SDK exception"
    client = TestClient(
        app,
    )
    try:
        with patch(
            "app.core.app_check.app_check.app_check.verify_token",
            side_effect=ValueError(
                secret,
            ),
        ) as verify:
            response = client.post(
                _PATH,
                json=_BODY,
                headers={"X-Firebase-AppCheck": "synthetic-secret-token"},
            )
        verify.assert_called_once_with(
            "synthetic-secret-token",
        )
    finally:
        client.close()
    assert response.status_code == 401
    assert response.json()["code"] == "invalidAppCheckToken"
    assert response.json()["requestId"] == response.headers["X-Request-ID"]
    assert secret not in response.text
    assert secret not in caplog.text
    assert "synthetic-secret-token" not in caplog.text
