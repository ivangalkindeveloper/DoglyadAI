from __future__ import annotations

from app.error.invalid_report_response_error import InvalidReportResponseError


class UnverifiedReportSectionError(InvalidReportResponseError):
    code = "unverifiedReportSection"
    description = "Unverified section inside report description"

    def __init__(
        self,
    ) -> None:
        super().__init__()
