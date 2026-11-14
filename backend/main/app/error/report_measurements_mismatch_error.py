from __future__ import annotations

from app.error.invalid_report_response_error import InvalidReportResponseError


class ReportMeasurementsMismatchError(InvalidReportResponseError):
    code = "reportMeasurementsMismatch"
    description = "Report measurements differ from the examination"

    def __init__(
        self,
    ) -> None:
        super().__init__()
