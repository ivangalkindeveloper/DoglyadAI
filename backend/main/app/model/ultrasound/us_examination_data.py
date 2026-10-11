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
    patientHeight: float | None = None
    patientWeight: float | None = None
    patientComplaints: str | None = None
    examinationDescription: str

    @field_validator("photos")
    @classmethod
    def reject_duplicate_photo_ids(cls, value: list[USExaminationScanPhoto]) -> list[USExaminationScanPhoto]:
        if len({photo.id for photo in value}) != len(value):
            raise ValueError("Photo IDs must be unique")
        return value

    @field_validator("patientComplaints")
    @classmethod
    def normalize_optional_complaints(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None
