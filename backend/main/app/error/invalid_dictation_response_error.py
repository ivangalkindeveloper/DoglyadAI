from __future__ import annotations

from app.error.api_error import ApiError


class InvalidDictationResponseError(ApiError):
    code = "invalidDictationResponse"
    description = "Invalid voice parse response"
    status_code = 502

    def __init__(
        self,
    ) -> None:
        super().__init__()
