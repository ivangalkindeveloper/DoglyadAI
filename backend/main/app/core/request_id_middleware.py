from __future__ import annotations

from uuid import uuid4

from fastapi import Request, Response
from starlette.middleware.base import RequestResponseEndpoint

from app.core.http_header import HttpHeader
from app.core.request_id_log_filter import current_request_id


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
