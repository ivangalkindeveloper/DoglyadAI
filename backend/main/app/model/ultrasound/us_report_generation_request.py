from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.model.ultrasound.us_examination_request import USExaminationRequest


class USReportGenerationRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )
    requestId: UUID
    examination: USExaminationRequest
    replacesGenerationId: UUID | None = None
