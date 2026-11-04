from __future__ import annotations

import asyncio
import json
from contextlib import aclosing

import httpx
import pytest

from app.core.variables import Variables
from app.error import InferenceBusyError, InvalidInferenceResponseError
from app.model.generation_request import GenerationRequest
from app.model.inference_server_config import InferenceServerConfig
from app.service.sse_decoder import SSEDecoder
from app.service.vllm_service import VLLMService
from tests.support.chunked_event_stream import ChunkedEventStream


def test_split_utf8_and_multiline_events_and_truncation() -> None:
    async def run() -> None:
        wire = "data: Привет\r\ndata: 世界\r\n\r\ndata: [DONE]\n\n".encode()
        response = httpx.Response(
            200,
            stream=ChunkedEventStream(
                [
                    bytes(
                        [byte],
                    )
                    for byte in wire
                ],
            ),
        )
        assert [
            value
            async for value in SSEDecoder(
                4096,
            ).messages(
                response,
            )
        ] == ["Привет\n世界", "[DONE]"]
        for raw in [b"data: truncated", b"data: truncated\n", b"data: \xff\n\n"]:
            with pytest.raises(
                ValueError,
            ):
                _ = [
                    value
                    async for value in SSEDecoder(
                        4096,
                    ).messages(
                        httpx.Response(
                            200,
                            stream=ChunkedEventStream(
                                [raw],
                            ),
                        ),
                    )
                ]
        with pytest.raises(
            ValueError,
        ):
            _ = [
                value
                async for value in SSEDecoder(
                    2,
                ).messages(
                    httpx.Response(
                        200,
                        stream=ChunkedEventStream(
                            [wire],
                        ),
                    ),
                )
            ]

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "finish,done",
    [("stop", True), ("length", True), ("stop", False)],
)
def test_stream_requires_successful_finish_and_forwards_text(
    server_config: InferenceServerConfig,
    finish: str,
    done: bool,
) -> None:
    async def run() -> None:
        content = '{"description":"Синтетический текст"}'
        frame = (
            "data: "
            + json.dumps(
                {"choices": [{"index": 0, "delta": {"content": content}, "finish_reason": None}]},
            )
            + "\n\n"
        )
        frame += (
            "data: "
            + json.dumps(
                {"choices": [{"index": 0, "delta": {}, "finish_reason": finish}]},
            )
            + "\n\n"
        )
        if done:
            frame += "data: [DONE]\n\n"
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda request: httpx.Response(
                    200,
                    stream=ChunkedEventStream(
                        [frame.encode()],
                    ),
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
            )
            if finish == "stop" and done:
                assert (
                    "".join(
                        [
                            part
                            async for part in service.stream(
                                request,
                            )
                        ],
                    )
                    == content
                )
            else:
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


def test_cancelled_stream_releases_capacity_immediately(
    server_config: InferenceServerConfig,
) -> None:
    async def run() -> None:
        config = server_config.model_copy(
            update={
                "generation": server_config.generation.model_copy(
                    update={"max_concurrent_requests": 1, "max_waiting_requests": 0},
                )
            },
        )
        frame = (
            "data: "
            + json.dumps(
                {"choices": [{"index": 0, "delta": {"content": "partial"}}]},
            )
            + "\n\n"
        )
        streams: list[ChunkedEventStream] = []

        def handler(
            request: httpx.Request,
        ) -> httpx.Response:
            assert (
                json.loads(
                    request.content,
                )["stream"]
                is True
            )
            source = ChunkedEventStream(
                [frame.encode()],
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
            )
            async with aclosing(
                service.stream(
                    request,
                ),
            ) as first:
                assert (
                    await anext(
                        first,
                    )
                    == "partial"
                )
                with pytest.raises(
                    InferenceBusyError,
                ):
                    await anext(
                        service.stream(
                            request,
                        ),
                    )
            assert streams[0].closed
            async with aclosing(
                service.stream(
                    request,
                ),
            ) as second:
                assert (
                    await anext(
                        second,
                    )
                    == "partial"
                )
            assert streams[1].closed

    asyncio.run(
        run(),
    )
