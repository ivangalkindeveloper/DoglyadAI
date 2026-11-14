from __future__ import annotations

from app.error.api_error import ApiError


class ReportGenerationNotFoundError(ApiError):
    code = "reportGenerationNotFound"
    description = "Generation not found or expired"
    status_code = 404

    def __init__(
        self,
    ) -> None:
        super().__init__()
