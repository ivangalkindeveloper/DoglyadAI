from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.model.ultrasound.us_examination_type import USExaminationType


class USExaminationTypeGroup(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    titleLocaleKey: str
    examinationTypes: list[USExaminationType] = Field(min_length=1)
