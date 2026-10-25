from __future__ import annotations

from app.error.invalid_report_response_error import InvalidReportResponseError


class UnexpectedReportRemarksError(InvalidReportResponseError):
    code = "unexpectedReportRemarks"
    description = "Report contains remarks that were not requested"
