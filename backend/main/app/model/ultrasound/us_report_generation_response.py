from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.model.non_blank_string import NonBlankString
from app.model.ultrasound.us_examination_model_report_response import USExaminationModelReportResponse
from app.model.ultrasound.us_report_generation_status import USReportGenerationStatus
from app.model.ultrasound.us_report_preview_response import USReportPreviewResponse


class USReportGenerationResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )
    modelId: NonBlankString
    generationId: UUID
    status: USReportGenerationStatus
    sequence: int
    expiresAt: datetime
    partialReport: USReportPreviewResponse
    report: USExaminationModelReportResponse | None = None
    errorCode: NonBlankString | None = None
