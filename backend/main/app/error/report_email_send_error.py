from __future__ import annotations

from app.error.api_error import ApiError


class ReportEmailSendError(ApiError):
    code = "reportEmailSendFailed"
    description = "Failed to send the report email"
    status_code = 500

    def __init__(
        self,
    ) -> None:
        super().__init__()
