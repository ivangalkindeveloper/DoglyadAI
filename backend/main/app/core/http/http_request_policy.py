from __future__ import annotations

from fastapi import Request, Response

from app.service.http.request_limiter import RequestLimiter


class HttpRequestPolicy:
    def __init__(
        self,
    ) -> None:
        pass

    @staticmethod
    async def enforce_limit(
        request: Request,
    ) -> None:
        limiter: RequestLimiter = request.app.state.request_limiter
        limiter.check(
            request,
        )

    @staticmethod
    async def prevent_cache(
        response: Response,
    ) -> None:
        response.headers["Cache-Control"] = "no-store"
