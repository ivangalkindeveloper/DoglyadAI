from __future__ import annotations

from app.error.api_error import ApiError


class ModelMismatchError(ApiError):
    code = "modelMismatch"
    description = "Requested model does not match the served model"
    status_code = 400
