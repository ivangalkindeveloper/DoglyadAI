from __future__ import annotations

from app.error.api_error import ApiError


class SpeechBusyError(ApiError):
    code = "speechBusy"
    description = "Speech recognition is busy"
    status_code = 503

    def __init__(
        self,
    ) -> None:
        super().__init__()

    @property
    def headers(
        self,
    ) -> dict[str, str]:
        return {"Retry-After": "5"}
