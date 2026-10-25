from __future__ import annotations

from app.error.api_error import ApiError


class TranscriptTooLongError(ApiError):
    code = "transcriptTooLong"
    description = "Transcript is too long"
    status_code = 422
