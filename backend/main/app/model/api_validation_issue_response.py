from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.non_blank_string import NonBlankString


class ApiValidationIssueResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )

    location: list[str | int]
    code: NonBlankString
    description: NonBlankString
