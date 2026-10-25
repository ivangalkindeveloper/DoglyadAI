from __future__ import annotations

from app.error.api_error import ApiError


class MissingAppCheckTokenError(ApiError):
    code = "missingAppCheckToken"
    description = "Missing App Check token"
    status_code = 401
