from __future__ import annotations

from app.error.api_error import ApiError


class RateLimitExceededError(ApiError):
    code = "rateLimitExceeded"
    description = "Too many requests"
    status_code = 429

    def __init__(self, retry_after_seconds: int = 60) -> None:
        self._retry_after_seconds = retry_after_seconds
        super().__init__()

    @property
    def headers(self) -> dict[str, str]:
        return {"Retry-After": str(self._retry_after_seconds)}
