from __future__ import annotations

from app.error.api_error import ApiError


class TooManyAttachmentsError(ApiError):
    code = "tooManyAttachments"
    description = "Too many attachments"
    status_code = 422
