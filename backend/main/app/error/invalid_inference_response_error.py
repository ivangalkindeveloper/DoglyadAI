from __future__ import annotations

from app.error.api_error import ApiError


class InvalidInferenceResponseError(ApiError):
    code = "invalidInferenceResponse"
    description = "Invalid response from inference service"
    status_code = 502

    def __init__(
        self,
    ) -> None:
        super().__init__()
