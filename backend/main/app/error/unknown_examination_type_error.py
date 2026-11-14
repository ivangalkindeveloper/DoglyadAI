from __future__ import annotations

from app.error.api_error import ApiError


class UnknownExaminationTypeError(ApiError):
    code = "unknownExaminationType"
    description = "Unknown examination type"
    status_code = 400

    def __init__(
        self,
    ) -> None:
        super().__init__()
