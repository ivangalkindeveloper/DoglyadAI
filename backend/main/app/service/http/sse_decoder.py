from __future__ import annotations

import codecs
from collections.abc import AsyncIterator

import httpx


class SSEDecoder:
    """Decode complete UTF-8 SSE events across arbitrary transport chunk boundaries."""

    def __init__(
        self,
        max_bytes: int,
    ) -> None:
        self._max_bytes = max_bytes

    async def messages(
        self,
        response: httpx.Response,
    ) -> AsyncIterator[str]:
        decoder = codecs.getincrementaldecoder(
            "utf-8",
        )(
            "strict",
        )
        buffer = ""
        data: list[str] = []
        size = 0
        async for chunk in response.aiter_bytes():
            size += len(
                chunk,
            )
            if size > self._max_bytes:
                raise ValueError(
                    "Stream exceeds the configured limit",
                )
            buffer += decoder.decode(
                chunk,
            )
            # CRLF can span chunks. Normalize only complete lines.
            while "\n" in buffer:
                line, buffer = buffer.split(
                    "\n",
                    1,
                )
                line = line.removesuffix(
                    "\r",
                )
                if not line:
                    if data:
                        yield "\n".join(
                            data,
                        )
                        data = []
                elif line.startswith(
                    "data:",
                ):
                    data.append(
                        line[5:].removeprefix(
                            " ",
                        ),
                    )
        buffer += decoder.decode(
            b"",
            final=True,
        )
        if buffer.strip() or data:
            raise ValueError(
                "Truncated event stream",
            )
