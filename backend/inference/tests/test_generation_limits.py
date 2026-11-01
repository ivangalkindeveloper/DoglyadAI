from __future__ import annotations

import asyncio
import json
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

from app.core.create_app import create_app
from app.core.variables import Variables
from app.error import ApiError
from app.model.generation_request import GenerationRequest
from app.model.inference_server_config import InferenceServerConfig
from app.service.generation_capacity import GenerationCapacity
from app.service.vllm_service import VLLMService


def test_queue_is_bounded_and_cancelled_requests_release_capacity(
    server_config: InferenceServerConfig,
) -> None:
    async def run() -> None:
        config = server_config.generation.model_copy(
            update={"max_concurrent_requests": 1, "max_waiting_requests": 1},
        )
        capacity = GenerationCapacity(
            config,
        )
        started = asyncio.Event()

        async def blocked() -> None:
            async with capacity.slot():
                started.set()
                await asyncio.Event().wait()

        first = asyncio.create_task(
            blocked(),
        )
        await started.wait()
        second = asyncio.create_task(
            blocked(),
        )
        await asyncio.sleep(
            0,
        )
        with pytest.raises(
            ApiError,
        ) as raised:
            async with capacity.slot():
                raise AssertionError(
                    "The queue must reject an extra request",
                )
        assert raised.value.status_code == 503
        assert raised.value.headers == {
            "Retry-After": str(
                config.retry_after_seconds,
            )
        }
        second.cancel()
        with pytest.raises(
            asyncio.CancelledError,
        ):
            await second
        first.cancel()
        with pytest.raises(
            asyncio.CancelledError,
        ):
            await first
        async with capacity.slot():
            pass

    asyncio.run(
        run(),
    )


def test_queue_wait_has_its_own_deadline(
    server_config: InferenceServerConfig,
) -> None:
    async def run() -> None:
        config = server_config.generation.model_copy(
            update={
                "max_concurrent_requests": 1,
                "max_waiting_requests": 1,
                "queue_timeout_seconds": 0.01,
            },
        )
        capacity = GenerationCapacity(
            config,
        )
        async with capacity.slot():
            with pytest.raises(
                ApiError,
            ) as raised:
                async with capacity.slot():
                    raise AssertionError(
                        "Waiting must time out",
                    )
            assert raised.value.status_code == 503
        async with capacity.slot():
            pass

    asyncio.run(
        run(),
    )


def test_generation_operation_deadline_includes_transport(
    server_config: InferenceServerConfig,
) -> None:
    async def handler(
        request: httpx.Request,
    ) -> httpx.Response:
        await asyncio.sleep(
            1,
        )
        raise AssertionError(
            "The transport must be cancelled",
        )

    async def run() -> None:
        config = server_config.model_copy(
            update={
                "vllm": server_config.vllm.model_copy(
                    update={"operation_timeout_seconds": 0.01},
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
                Variables(),
                config,
            )
            with pytest.raises(
                ApiError,
            ) as raised:
                await service.generate(
                    GenerationRequest(
                        modelId="example/served-model",
                        prompt="Synthetic input",
                    ),
                )
        assert raised.value.status_code == 504

    asyncio.run(
        run(),
    )


def test_inference_body_limit_is_loaded_before_authentication(
    server_config: InferenceServerConfig,
    tmp_path: Path,
) -> None:
    document = server_config.model_dump()
    document["generation"]["max_body_bytes"] = 8
    (tmp_path / "server.json").write_text(
        json.dumps(
            document,
        ),
    )
    app = create_app(
        Variables(
            config_dir=tmp_path,
        ),
    )
    client = TestClient(
        app,
    )
    try:
        assert (
            client.post(
                "/v1/generation",
                content=b"invalid-json-too-large",
            ).status_code
            == 413
        )
        assert (
            client.post(
                "/v1/generation",
                json={},
            ).status_code
            == 401
        )
    finally:
        client.close()
