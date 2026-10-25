from __future__ import annotations

from starlette.requests import Request
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.core.api_error_handler import ApiErrorHandler


class ApiErrorMiddleware:
    """Handle unexpected failures before the ASGI server can log raw exception text."""

    def __init__(self, app: ASGIApp, error_handler: ApiErrorHandler) -> None:
        self._app = app
        self._error_handler = error_handler

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self._app(scope, receive, send)
            return
        is_response_started = False

        async def tracked_send(message: Message) -> None:
            nonlocal is_response_started
            if message["type"] == "http.response.start":
                is_response_started = True
            await send(message)

        try:
            await self._app(scope, receive, tracked_send)
        except Exception as error:
            response = await self._error_handler.handle(Request(scope), error)
            if not is_response_started:
                try:
                    await response(scope, receive, send)
                except Exception as send_error:
                    await self._error_handler.handle(Request(scope), send_error)
