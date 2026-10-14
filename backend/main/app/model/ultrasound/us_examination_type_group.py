from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.model.non_blank_string import NonBlankString
from app.model.ultrasound.us_examination_type import USExaminationType


class USExaminationTypeGroup(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: NonBlankString
    titleLocaleKey: NonBlankString
    examinationTypes: list[USExaminationType] = Field(min_length=1)
