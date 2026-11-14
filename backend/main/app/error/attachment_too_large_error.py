from __future__ import annotations

from app.error.api_error import ApiError


class AttachmentTooLargeError(ApiError):
    code = "attachmentTooLarge"
    description = "Attachment is too large"
    status_code = 413

    def __init__(
        self,
    ) -> None:
        super().__init__()
