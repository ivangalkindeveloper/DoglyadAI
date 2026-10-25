from __future__ import annotations

from app.error.api_error import ApiError


class InvalidImageEncodingError(ApiError):
    code = "invalidImageEncoding"
    description = "Invalid image encoding"
    status_code = 422
