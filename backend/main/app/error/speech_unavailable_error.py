from __future__ import annotations

from app.error.api_error import ApiError


class SpeechUnavailableError(ApiError):
    code = "speechUnavailable"
    description = "Speech recognition is unavailable"
    status_code = 503

    def __init__(
        self,
    ) -> None:
        super().__init__()
