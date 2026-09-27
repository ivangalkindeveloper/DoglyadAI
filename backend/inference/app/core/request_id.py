from __future__ import annotations

import logging
import re
from contextvars import ContextVar
from uuid import uuid4

from fastapi import Request, Response
from starlette.middleware.base import RequestResponseEndpoint

from app.core.http_header import HttpHeader

current_request_id: ContextVar[str] = ContextVar("request_id", default="-")
_REQUEST_ID_PATTERN = re.compile(r"[0-9a-f]{32}")


class RequestIdLogFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = current_request_id.get()
        return True


async def request_id_middleware(request: Request, call_next: RequestResponseEndpoint) -> Response:
    incoming_id = request.headers.get(HttpHeader.REQUEST_ID.value)
    request_id = incoming_id if incoming_id and _REQUEST_ID_PATTERN.fullmatch(incoming_id) else uuid4().hex
    request.state.request_id = request_id
    token = current_request_id.set(request_id)
    try:
        response = await call_next(request)
        response.headers[HttpHeader.REQUEST_ID.value] = request_id
        return response
    finally:
        current_request_id.reset(token)
