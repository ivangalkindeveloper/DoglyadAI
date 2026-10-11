from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.model.ultrasound.us_examination_photo_remark_point import USExaminationPhotoRemarkPoint
from app.model.ultrasound.us_examination_report import USExaminationReport


class MockReportFixture(BaseModel):
    model_config = ConfigDict(extra="forbid")

    report: USExaminationReport
    photoRemarkPoints: list[USExaminationPhotoRemarkPoint] = Field(min_length=1)
