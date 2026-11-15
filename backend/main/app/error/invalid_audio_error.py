from __future__ import annotations

from app.error.api_error import ApiError


class InvalidAudioError(ApiError):
    code = "invalidAudio"
    description = "Expected Russian mono PCM16 little-endian audio at 8000 Hz, up to 300 seconds"
    status_code = 422

    def __init__(
        self,
    ) -> None:
        super().__init__()
