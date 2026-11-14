from __future__ import annotations

from app.error.api_error import ApiError


class ReportGenerationUnavailableError(ApiError):
    code = "reportGenerationUnavailable"
    description = "Report generation is unavailable"
    status_code = 503

    def __init__(
        self,
    ) -> None:
        super().__init__()
