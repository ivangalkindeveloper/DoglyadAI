from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator

import httpx


class ChunkedEventStream(httpx.AsyncByteStream):
    def __init__(
        self,
        chunks: list[bytes],
        *,
        is_blocked: bool = False,
    ) -> None:
        self.chunks = chunks
        self.is_blocked = is_blocked
        self.closed = False

    async def __aiter__(
        self,
    ) -> AsyncIterator[bytes]:
        for chunk in self.chunks:
            yield chunk
        if self.is_blocked:
            await asyncio.Event().wait()

    async def aclose(
        self,
    ) -> None:
        self.closed = True
