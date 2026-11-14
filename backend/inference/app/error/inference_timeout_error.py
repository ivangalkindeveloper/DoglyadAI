from __future__ import annotations

from app.error.api_error import ApiError


class InferenceTimeoutError(ApiError):
    code = "inferenceTimeout"
    description = "Inference service timed out"
    status_code = 504

    def __init__(
        self,
    ) -> None:
        super().__init__()
