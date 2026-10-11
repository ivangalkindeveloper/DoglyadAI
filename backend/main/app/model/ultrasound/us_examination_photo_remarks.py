from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.model.ultrasound.us_examination_photo_remark_point import USExaminationPhotoRemarkPoint


class USExaminationPhotoRemarks(BaseModel):
    model_config = ConfigDict(extra="forbid")

    photoId: UUID
    points: list[USExaminationPhotoRemarkPoint] = Field(min_length=1)
