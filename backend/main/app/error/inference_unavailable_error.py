from __future__ import annotations

from app.error.api_error import ApiError


class InferenceUnavailableError(ApiError):
    code = "inferenceUnavailable"
    description = "Inference service is unavailable"
    status_code = 502
