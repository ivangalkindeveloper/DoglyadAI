from __future__ import annotations

from pydantic import BaseModel, Field

from app.model.ultrasound.us_examination_type_response import USExaminationTypeResponse


class USExaminationTypeGroupResponse(BaseModel):
    id: str
    title: str
    examinationTypes: list[USExaminationTypeResponse] = Field(min_length=1)
