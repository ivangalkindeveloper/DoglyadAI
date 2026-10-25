from __future__ import annotations

from app.error.api_error import ApiError


class InternalServerError(ApiError):
    code = "internalServerError"
    description = "Internal server error"
    status_code = 500
