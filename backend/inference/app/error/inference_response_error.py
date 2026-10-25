from __future__ import annotations

from app.error.api_error import ApiError


class InferenceResponseError(ApiError):
    code = "inferenceResponseError"
    description = "Inference service returned an error"
    status_code = 502
