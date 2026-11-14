from __future__ import annotations

from app.error.api_error import ApiError


class InvalidReportResponseError(ApiError):
    code = "invalidReportResponse"
    description = "Invalid report from inference service"
    status_code = 502

    def __init__(
        self,
    ) -> None:
        super().__init__()
