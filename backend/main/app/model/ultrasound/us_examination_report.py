from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.model.non_blank_string import NonBlankString
from app.model.ultrasound.us_examination_photo_remarks import USExaminationPhotoRemarks


class USExaminationReport(BaseModel):
    model_config = ConfigDict(extra="forbid")

    description: NonBlankString = Field(min_length=1)
    conclusion: NonBlankString = Field(min_length=1)
    recommendations: str | None = None
    descriptionRemarks: str | None = None
    photoRemarks: list[USExaminationPhotoRemarks] = Field(default_factory=list)

    @field_validator("description", "conclusion")
    @classmethod
    def reject_blank_sections(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("Report sections must not be blank")
        return stripped

    @field_validator("recommendations", "descriptionRemarks")
    @classmethod
    def normalize_optional_sections(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None
