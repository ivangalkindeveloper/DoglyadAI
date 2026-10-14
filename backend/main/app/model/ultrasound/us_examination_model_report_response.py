from __future__ import annotations

from datetime import datetime

from app.model.non_blank_string import NonBlankString
from app.model.ultrasound.us_examination_report import USExaminationReport


class USExaminationModelReportResponse(USExaminationReport):
    date: datetime
    modelId: NonBlankString
