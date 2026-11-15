from __future__ import annotations

from app.error.api_error import ApiError


class NoSpeechError(ApiError):
    code = "noSpeech"
    description = "No speech was recognized"
    status_code = 422

    def __init__(
        self,
    ) -> None:
        super().__init__()
