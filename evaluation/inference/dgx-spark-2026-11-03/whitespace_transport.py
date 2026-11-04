"""Test equivalent whitespace-enabled grammar without restarting live engines."""

from __future__ import annotations

import json
from typing import Any

import httpx


class WhitespaceTransport(httpx.AsyncBaseTransport):
    def __init__(self, case: dict[str, Any]) -> None:
        self.case = case
        self.transport = httpx.AsyncHTTPTransport()

    async def handle_async_request(self, request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content)
        payload.pop("response_format", None)
        payload["structured_outputs"] = {"grammar": self.case["grammar"]}
        payload["seed"] = 0
        if self.case.get("min_tokens"):
            payload["min_tokens"] = self.case["min_tokens"]
        forwarded = httpx.Request(
            request.method,
            request.url,
            json=payload,
            headers={k: v for k, v in request.headers.items() if k != "content-length"},
            extensions=request.extensions,
        )
        return await self.transport.handle_async_request(forwarded)

    async def aclose(self) -> None:
        await self.transport.aclose()
