from __future__ import annotations

from app.error.api_error import ApiError


class UnknownNeuralModelError(ApiError):
    code = "unknownNeuralModel"
    description = "Unknown neural model"
    status_code = 400
