from __future__ import annotations

from pydantic import BaseModel, Field

from app.model.ultrasound.us_examination_type import USExaminationType


class USExaminationTypeGroup(BaseModel):
    id: str
    title: dict[str, str]
    examinationTypes: list[USExaminationType] = Field(min_length=1)
