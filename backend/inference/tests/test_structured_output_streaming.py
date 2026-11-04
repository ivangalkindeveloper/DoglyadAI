from __future__ import annotations

import asyncio
import json
from contextlib import aclosing

import httpx
import pytest

from app.core.variables import Variables
from app.error import InferenceTimeoutError, InvalidInferenceResponseError
from app.model.generation_request import GenerationRequest
from app.model.inference_server_config import InferenceServerConfig
from app.service.vllm_service import VLLMService
from tests.support.chunked_event_stream import ChunkedEventStream
from tests.support.vllm_stream_response import vllm_stream_response


@pytest.mark.parametrize(
    "is_stream",
    [False, True],
)
@pytest.mark.parametrize(
    "finish",
    [None, "length"],
)
def test_complete_json_closes_blocked_upstream_without_done(
    server_config: InferenceServerConfig,
    is_stream: bool,
    finish: str | None,
) -> None:
    async def run() -> None:
        content = '{"description":"Synthetic } text"}'
        wire = (
            "data: "
            + json.dumps(
                {"choices": [{"index": 0, "delta": {"content": content + "\n\n"}, "finish_reason": finish}]},
            )
            + "\n\n"
        )
        streams: list[ChunkedEventStream] = []
        config = server_config.model_copy(
            update={
                "generation": server_config.generation.model_copy(
                    update={"max_concurrent_requests": 1, "max_waiting_requests": 0},
                )
            },
        )

        def handler(
            request: httpx.Request,
        ) -> httpx.Response:
            source = ChunkedEventStream(
                [wire.encode()],
                is_blocked=True,
            )
            streams.append(
                source,
            )
            return httpx.Response(
                200,
                stream=source,
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
            request = GenerationRequest(
                modelId="example/served-model",
                prompt="Synthetic",
                structuredOutput='{"type":"object","required":["description"]}',
            )
            if is_stream:
                async with aclosing(
                    service.stream(
                        request,
                    ),
                ) as source:
                    assert (
                        await asyncio.wait_for(
                            anext(
                                source,
                            ),
                            timeout=1,
                        )
                        == content
                    )
                    assert streams[0].closed
                    # The first consumer has not resumed after its final delta, but
                    # HTTP and the model slot must already be released.
                    assert (
                        await asyncio.wait_for(
                            service.generate(
                                request,
                            ),
                            timeout=1,
                        )
                        == content
                    )
            else:
                assert (
                    await asyncio.wait_for(
                        service.generate(
                            request,
                        ),
                        timeout=1,
                    )
                    == content
                )
                assert streams[0].closed
                assert (
                    await asyncio.wait_for(
                        service.generate(
                            request,
                        ),
                        timeout=1,
                    )
                    == content
                )
            assert all(
                (source.closed for source in streams),
            )

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "content",
    ["{}", '{"description":3}', '{"description":"unfinished', '{"description":"ok"} garbage'],
)
def test_both_methods_reject_invalid_structured_response(
    server_config: InferenceServerConfig,
    content: str,
) -> None:
    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda request: vllm_stream_response(
                    content,
                ),
            ),
        ) as client:
            service = VLLMService(
                client,
                Variables(),
                server_config,
            )
            request = GenerationRequest(
                modelId="example/served-model",
                prompt="Synthetic",
                structuredOutput='{"type":"object","properties":{"description":{"type":"string"}},"required":["description"]}',
            )
            with pytest.raises(
                InvalidInferenceResponseError,
            ):
                await service.generate(
                    request,
                )
            with pytest.raises(
                InvalidInferenceResponseError,
            ):
                _ = [
                    part
                    async for part in service.stream(
                        request,
                    )
                ]

    asyncio.run(
        run(),
    )


def test_incomplete_structured_response_keeps_absolute_timeout_and_closes_http(
    server_config: InferenceServerConfig,
) -> None:
    async def run() -> None:
        frame = (
            "data: "
            + json.dumps(
                {"choices": [{"delta": {"content": '{"description":"partial'}}]},
            )
            + "\n\n"
        )
        source = ChunkedEventStream(
            [frame.encode()],
            is_blocked=True,
        )
        config = server_config.model_copy(
            update={
                "vllm": server_config.vllm.model_copy(
                    update={"operation_timeout_seconds": 0.02},
                )
            },
        )
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda request: httpx.Response(
                    200,
                    stream=source,
                ),
            ),
        ) as client:
            service = VLLMService(
                client,
                Variables(),
                config,
            )
            with pytest.raises(
                InferenceTimeoutError,
            ):
                await service.generate(
                    GenerationRequest(
                        modelId="example/served-model",
                        prompt="Synthetic",
                        structuredOutput='{"type":"object"}',
                    ),
                )
            assert source.closed

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "content",
    ["", "   "],
)
def test_plain_generation_rejects_empty_output(
    server_config: InferenceServerConfig,
    content: str,
) -> None:
    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda request: vllm_stream_response(
                    content,
                ),
            ),
        ) as client:
            service = VLLMService(
                client,
                Variables(),
                server_config,
            )
            with pytest.raises(
                InvalidInferenceResponseError,
            ):
                await service.generate(
                    GenerationRequest(
                        modelId="example/served-model",
                        prompt="Synthetic",
                    ),
                )

    asyncio.run(
        run(),
    )
