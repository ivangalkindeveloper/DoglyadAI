from __future__ import annotations

from app.error.api_error import ApiError
from app.model.api_validation_issue_response import ApiValidationIssueResponse


class TextTooLongError(ApiError):
    code = "textTooLong"
    description = "Text exceeds the allowed length"
    status_code = 422

    def __init__(self, location: list[str | int]) -> None:
        self._location = location
        super().__init__()

    @property
    def fields(self) -> list[ApiValidationIssueResponse]:
        return [
            ApiValidationIssueResponse(location=self._location, code="string_too_long", description=self.description)
        ]
