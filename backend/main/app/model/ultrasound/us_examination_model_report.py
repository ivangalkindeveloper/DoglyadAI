from __future__ import annotations

from datetime import datetime

from app.model.ultrasound.us_examination_report import USExaminationReport


class USExaminationModelReport(USExaminationReport):
    date: datetime
    modelId: str
