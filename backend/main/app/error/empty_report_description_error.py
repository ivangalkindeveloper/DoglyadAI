from __future__ import annotations

from app.error.invalid_report_response_error import InvalidReportResponseError


class EmptyReportDescriptionError(InvalidReportResponseError):
    code = "emptyReportDescription"
    description = "No findings remain in report description"

    def __init__(
        self,
    ) -> None:
        super().__init__()
