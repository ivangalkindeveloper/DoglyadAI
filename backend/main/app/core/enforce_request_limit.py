from __future__ import annotations

from fastapi import Request

from app.service.request_limiter import RequestLimiter


async def enforce_request_limit(request: Request) -> None:
    limiter: RequestLimiter = request.app.state.request_limiter
    limiter.check(request)
