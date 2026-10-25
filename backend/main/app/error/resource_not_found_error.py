from __future__ import annotations

from app.error.api_error import ApiError


class ResourceNotFoundError(ApiError):
    code = "resourceNotFound"
    description = "Resource not found"
    status_code = 404
