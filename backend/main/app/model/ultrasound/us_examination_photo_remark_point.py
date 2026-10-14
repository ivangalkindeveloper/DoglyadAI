from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.model.non_blank_string import NonBlankString


class USExaminationPhotoRemarkPoint(BaseModel):
    model_config = ConfigDict(extra="forbid")

    x: float = Field(ge=0, le=1, allow_inf_nan=False)
    y: float = Field(ge=0, le=1, allow_inf_nan=False)
    title: NonBlankString = Field(min_length=1)
    description: NonBlankString = Field(min_length=1)

    @field_validator("title", "description")
    @classmethod
    def reject_blank_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Photo remark title and description must not be blank")
        return value
