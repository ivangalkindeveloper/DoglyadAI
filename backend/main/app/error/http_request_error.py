from __future__ import annotations

from app.error.api_error import ApiError


class HttpRequestError(ApiError):
    code = "httpRequestFailed"
    description = "The HTTP request could not be completed"

    def __init__(
        self,
        status_code: int,
        headers: dict[str, str] | None = None,
    ) -> None:
        self.status_code = status_code if 400 <= status_code <= 599 else 500
        self._headers = headers
        super().__init__()

    @property
    def headers(
        self,
    ) -> dict[str, str] | None:
        return self._headers
