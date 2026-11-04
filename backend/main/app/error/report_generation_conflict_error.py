from __future__ import annotations

from app.error.api_error import ApiError


class ReportGenerationConflictError(ApiError):
    code = "reportGenerationConflict"
    description = "Generation request conflicts with an existing operation"
    status_code = 409
