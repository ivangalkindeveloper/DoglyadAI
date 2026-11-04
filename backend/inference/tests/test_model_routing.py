from __future__ import annotations

import asyncio
import json

import httpx
import pytest
from fastapi import FastAPI
from pydantic import ValidationError

from app.core.get_vllm_service import get_vllm_service
from app.core.variables import Variables
from app.core.verify_app_check import verify_app_check
from app.error import InferenceBusyError, InferenceUnavailableError, ModelMismatchError
from app.model.generation_request import GenerationRequest
from app.model.inference_server_config import InferenceServerConfig
from app.service.vllm_service import VLLMService
from tests.support.vllm_stream_response import vllm_stream_response


@pytest.fixture
def routing_variables(
    monkeypatch: pytest.MonkeyPatch,
) -> Variables:
    monkeypatch.setenv(
        "SERVED_MODEL_ID",
        "",
    )
    monkeypatch.setenv(
        "VLLM_ENDPOINTS",
        json.dumps(
            {
                "example/4b": "http://engine-4b:8000",
                "example/15-4b": "http://engine-15-4b:8000",
                "example/27b": "http://engine-27b:8000",
            },
        ),
    )
    return Variables()


def test_each_model_uses_its_configured_engine_and_response_id(
    app: FastAPI,
    server_config: InferenceServerConfig,
    routing_variables: Variables,
) -> None:
    seen: list[tuple[str, str, str]] = []

    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        payload = json.loads(
            request.content,
        )
        seen.append(
            (
                str(
                    request.url,
                ),
                payload["model"],
                payload["messages"][0]["content"][0]["text"],
            ),
        )
        return vllm_stream_response(
            payload["model"],
        )

    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                handler,
            ),
        ) as upstream:
            service = VLLMService(
                upstream,
                routing_variables,
                server_config,
            )

            async def verified() -> None:
                pass

            async def get_service() -> VLLMService:
                return service

            # Unit test only: the deployed application has no authentication bypass.
            app.dependency_overrides[verify_app_check] = verified
            app.dependency_overrides[get_vllm_service] = get_service
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(
                    app=app,
                ),
                base_url="http://test",
            ) as client:
                for model_id in service.model_ids:
                    response = await client.post(
                        "/v1/generation",
                        json={"modelId": model_id, "prompt": "Synthetic input"},
                    )
                    assert response.status_code == 200
                    assert response.json() == {"modelId": model_id, "response": model_id}
                rejected = await client.post(
                    "/v1/generation",
                    json={"modelId": "example/unknown", "prompt": "Synthetic input"},
                )
                assert rejected.status_code == 400
                assert rejected.json()["code"] == "modelMismatch"
            app.dependency_overrides.clear()

    asyncio.run(
        run(),
    )
    assert seen == [
        (f"{url}/v1/chat/completions", model_id, "Synthetic input")
        for model_id, url in routing_variables.model_endpoints.items()
    ]


def test_unknown_model_never_reaches_an_engine(
    server_config: InferenceServerConfig,
    routing_variables: Variables,
) -> None:
    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        raise AssertionError(
            "Unknown model must not reach any engine",
        )

    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                handler,
            ),
        ) as client:
            service = VLLMService(
                client,
                routing_variables,
                server_config,
            )
            with pytest.raises(
                ModelMismatchError,
            ):
                await service.generate(
                    GenerationRequest(
                        modelId="http://caller-supplied-host:8000",
                        prompt="Synthetic input",
                    ),
                )

    asyncio.run(
        run(),
    )


def test_busy_model_does_not_block_another_and_cancellation_releases_its_slot(
    server_config: InferenceServerConfig,
    routing_variables: Variables,
) -> None:
    async def run() -> None:
        started = asyncio.Event()
        release = asyncio.Event()

        async def handler(
            request: httpx.Request,
        ) -> httpx.Response:
            if request.url.host == "engine-27b":
                started.set()
                await release.wait()
            return vllm_stream_response(
                "Synthetic result",
            )

        config = server_config.model_copy(
            update={
                "generation": server_config.generation.model_copy(
                    update={
                        "max_concurrent_requests": 1,
                        "max_waiting_requests": 1,
                        "queue_timeout_seconds": 10,
                    },
                )
            },
        )
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                handler,
            ),
        ) as client:
            service = VLLMService(
                client,
                routing_variables,
                config,
            )
            large = GenerationRequest(
                modelId="example/27b",
                prompt="Synthetic input",
            )
            first = asyncio.create_task(
                service.generate(
                    large,
                ),
            )
            await asyncio.wait_for(
                started.wait(),
                timeout=1,
            )
            second = asyncio.create_task(
                service.generate(
                    large,
                ),
            )
            await asyncio.sleep(
                0,
            )
            try:
                with pytest.raises(
                    InferenceBusyError,
                ):
                    await service.generate(
                        large,
                    )
                assert (
                    await asyncio.wait_for(
                        service.generate(
                            GenerationRequest(
                                modelId="example/4b",
                                prompt="Synthetic input",
                            ),
                        ),
                        timeout=1,
                    )
                    == "Synthetic result"
                )
            finally:
                first.cancel()
                second.cancel()
                await asyncio.gather(
                    first,
                    second,
                    return_exceptions=True,
                )
            release.set()
            assert (
                await service.generate(
                    large,
                )
                == "Synthetic result"
            )

    asyncio.run(
        run(),
    )


def test_engine_failure_is_isolated_to_its_model(
    server_config: InferenceServerConfig,
    routing_variables: Variables,
) -> None:
    def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        if request.url.host == "engine-27b":
            raise httpx.ConnectError(
                "Synthetic unavailable engine",
                request=request,
            )
        return vllm_stream_response(
            "Synthetic result",
        )

    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                handler,
            ),
        ) as client:
            service = VLLMService(
                client,
                routing_variables,
                server_config,
            )
            with pytest.raises(
                InferenceUnavailableError,
            ):
                await service.generate(
                    GenerationRequest(
                        modelId="example/27b",
                        prompt="Synthetic input",
                    ),
                )
            assert (
                await service.generate(
                    GenerationRequest(
                        modelId="example/4b",
                        prompt="Synthetic input",
                    ),
                )
                == "Synthetic result"
            )

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "endpoints",
    [
        {},
        {"": "http://engine:8000"},
        {"example/model": "file:///tmp/engine"},
        {"example/model": "http://user:secret@engine:8000"},
        {"example/model": "http://engine:8000?model=other"},
        {"example/model": "http://engine:8000#fragment"},
    ],
)
def test_invalid_routes_fail_startup(
    monkeypatch: pytest.MonkeyPatch,
    endpoints: dict[str, str],
) -> None:
    monkeypatch.setenv(
        "SERVED_MODEL_ID",
        "",
    )
    monkeypatch.setenv(
        "VLLM_ENDPOINTS",
        json.dumps(
            endpoints,
        ),
    )
    with pytest.raises(
        ValidationError,
    ):
        Variables()


def test_ambiguous_or_missing_model_configuration_fails_startup(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv(
        "VLLM_ENDPOINTS",
        '{"example/model":"http://engine:8000"}',
    )
    monkeypatch.setenv(
        "SERVED_MODEL_ID",
        "example/legacy",
    )
    with pytest.raises(
        ValidationError,
    ):
        Variables()
    monkeypatch.delenv(
        "VLLM_ENDPOINTS",
    )
    monkeypatch.delenv(
        "SERVED_MODEL_ID",
    )
    with pytest.raises(
        ValidationError,
    ):
        Variables()


def test_single_model_configuration_remains_supported(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv(
        "VLLM_ENDPOINTS",
        raising=False,
    )
    monkeypatch.setenv(
        "SERVED_MODEL_ID",
        "example/legacy",
    )
    monkeypatch.setenv(
        "VLLM_BASE_URL",
        "http://legacy-engine:8000/",
    )
    assert Variables().model_endpoints == {"example/legacy": "http://legacy-engine:8000"}
