from __future__ import annotations

import logging
from contextvars import ContextVar
from uuid import uuid4

from fastapi import Request, Response
from starlette.middleware.base import RequestResponseEndpoint

from app.core.http_header import HttpHeader

current_request_id: ContextVar[str] = ContextVar("request_id", default="-")


class RequestIdLogFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = current_request_id.get()
        return True


async def request_id_middleware(request: Request, call_next: RequestResponseEndpoint) -> Response:
    request_id = uuid4().hex
    request.state.request_id = request_id
    token = current_request_id.set(request_id)
    try:
        response = await call_next(request)
        response.headers[HttpHeader.REQUEST_ID.value] = request_id
        return response
    finally:
        current_request_id.reset(token)
