from __future__ import annotations

from pydantic import BaseModel, Field

from app.model.non_blank_string import NonBlankString
from app.model.ultrasound.us_examination_type_response import USExaminationTypeResponse


class USExaminationTypeGroupResponse(BaseModel):
    id: NonBlankString
    title: NonBlankString
    examinationTypes: list[USExaminationTypeResponse] = Field(min_length=1)
