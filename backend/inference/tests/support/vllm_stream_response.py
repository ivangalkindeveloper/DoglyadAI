from __future__ import annotations

import json

import httpx
from tests.support.chunked_event_stream import ChunkedEventStream


def vllm_stream_response(
    content: str,
) -> httpx.Response:
    event = {"choices": [{"index": 0, "delta": {"content": content}, "finish_reason": "stop"}]}
    wire = (
        "data: "
        + json.dumps(
            event,
        )
        + "\n\ndata: [DONE]\n\n"
    )
    return httpx.Response(
        200,
        stream=ChunkedEventStream(
            [wire.encode()],
        ),
    )
