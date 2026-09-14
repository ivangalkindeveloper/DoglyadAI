from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, field_validator

from app.model.ultrasound.us_examination_scan_photo import USExaminationScanPhoto


class USExaminationData(BaseModel):
    usExaminationTypeId: str
    photos: list[USExaminationScanPhoto]
    examinationNumber: str
    patientName: str
    patientGender: str
    patientDateOfBirth: datetime
    patientHeight: float
    patientWeight: float
    patientComplaint: str | None = None
    examinationDescription: str

    @field_validator("patientComplaint")
    @classmethod
    def normalize_optional_complaint(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None
