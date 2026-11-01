from __future__ import annotations

from starlette.requests import Request
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.core.api_error_handler import ApiErrorHandler
from app.error import RequestBodyTooLargeError


class RequestBodyLimitMiddleware:
    """Bound actual received bytes before FastAPI decodes JSON, including chunked requests."""

    def __init__(
        self,
        app: ASGIApp,
        limits: dict[str, int],
        default_limit: int,
        error_handler: ApiErrorHandler,
    ) -> None:
        self._app = app
        self._limits = dict(
            limits,
        )
        self._default_limit = default_limit
        self._error_handler = error_handler

    async def __call__(
        self,
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        if scope["type"] != "http":
            await self._app(
                scope,
                receive,
                send,
            )
            return
        limit = self._limits.get(
            scope["path"],
            self._default_limit,
        )
        request = Request(
            scope,
        )
        content_length = request.headers.get(
            "content-length",
        )
        if (
            content_length is not None
            and content_length.isdecimal()
            and int(
                content_length,
            )
            > limit
        ):
            await self._error_handler.response(
                RequestBodyTooLargeError(),
                request,
            )(
                scope,
                receive,
                send,
            )
            return
        chunks: list[bytes] = []
        size = 0
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            chunk = message.get(
                "body",
                b"",
            )
            size += len(
                chunk,
            )
            if size > limit:
                await self._error_handler.response(
                    RequestBodyTooLargeError(),
                    request,
                )(
                    scope,
                    receive,
                    send,
                )
                return
            chunks.append(
                chunk,
            )
            if not message.get(
                "more_body",
                False,
            ):
                break
        body = b"".join(
            chunks,
        )
        is_delivered = False

        async def replay() -> Message:
            nonlocal is_delivered
            if not is_delivered:
                is_delivered = True
                return {"type": "http.request", "body": body, "more_body": False}
            return await receive()

        await self._app(
            scope,
            replay,
            send,
        )
