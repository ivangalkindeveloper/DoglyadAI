from __future__ import annotations

from app.error.invalid_report_response_error import InvalidReportResponseError


class InvalidPhotoRemarksError(InvalidReportResponseError):
    code = "invalidPhotoRemarks"
    description = "Report contains invalid photo references"

    def __init__(
        self,
    ) -> None:
        super().__init__()
