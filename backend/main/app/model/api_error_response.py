from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.api_validation_issue_response import ApiValidationIssueResponse
from app.model.non_blank_string import NonBlankString


class ApiErrorResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )

    code: NonBlankString
    detail: NonBlankString
    requestId: NonBlankString
    fields: list[ApiValidationIssueResponse] | None = None
