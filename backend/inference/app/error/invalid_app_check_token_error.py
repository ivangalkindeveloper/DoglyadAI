from __future__ import annotations

from app.error.api_error import ApiError


class InvalidAppCheckTokenError(ApiError):
    code = "invalidAppCheckToken"
    description = "Invalid App Check token"
    status_code = 401

    def __init__(
        self,
    ) -> None:
        super().__init__()
