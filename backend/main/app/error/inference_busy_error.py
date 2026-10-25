from __future__ import annotations

from typing import Self

from app.error.api_error import ApiError


class InferenceBusyError(ApiError):
    code = "inferenceBusy"
    description = "Inference service is busy"
    status_code = 503
    _default_retry_after_seconds = 5

    def __init__(self, retry_after_seconds: int = _default_retry_after_seconds) -> None:
        self._retry_after_seconds = retry_after_seconds
        super().__init__()

    @property
    def headers(self) -> dict[str, str]:
        return {"Retry-After": str(self._retry_after_seconds)}

    @classmethod
    def from_retry_after(cls, value: str | None) -> Self:
        try:
            seconds = int(value) if value is not None else cls._default_retry_after_seconds
        except ValueError:
            seconds = cls._default_retry_after_seconds
        return cls(seconds if seconds >= 0 else cls._default_retry_after_seconds)
