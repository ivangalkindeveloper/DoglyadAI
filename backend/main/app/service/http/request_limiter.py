from __future__ import annotations

from fastapi import Request
from limits import RateLimitItemPerMinute
from limits.storage import MemoryStorage
from limits.strategies import FixedWindowRateLimiter

from app.error import RateLimitExceededError
from app.model.endpoint_config import EndpointConfig


class RequestLimiter:
    """Per-application IP limits. Each worker owns its own in-memory counters."""

    def __init__(
        self,
        endpoints: dict[str, EndpointConfig],
    ) -> None:
        self._limiter = FixedWindowRateLimiter(
            MemoryStorage(),
        )
        self._limits = {
            path: RateLimitItemPerMinute(
                config.requests_per_minute,
            )
            for path, config in endpoints.items()
        }

    def check(
        self,
        request: Request,
    ) -> None:
        limit = self._limits[request.url.path]
        address = request.client.host if request.client else "unknown"
        if not self._limiter.hit(
            limit,
            request.url.path,
            address,
        ):
            raise RateLimitExceededError()
