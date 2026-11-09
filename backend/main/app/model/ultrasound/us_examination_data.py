from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

from app.model.ultrasound.us_examination_scan_photo import USExaminationScanPhoto


class USExaminationData(BaseModel):
    usExaminationTypeId: str
    photos: list[USExaminationScanPhoto]
    examinationNumber: str
    patientName: str
    patientGender: Literal["male", "female"]
    patientDateOfBirth: datetime
    isPatientConsent: bool
    patientHeight: float | None = Field(
        default=None,
        gt=0,
        allow_inf_nan=False,
        strict=True,
    )
    patientWeight: float | None = Field(
        default=None,
        gt=0,
        allow_inf_nan=False,
        strict=True,
    )
    patientComplaints: str | None = None
    examinationDescription: str

    @field_validator(
        "photos",
    )
    @classmethod
    def reject_duplicate_photo_ids(
        cls,
        value: list[USExaminationScanPhoto],
    ) -> list[USExaminationScanPhoto]:
        if len(
            {photo.id for photo in value},
        ) != len(
            value,
        ):
            raise ValueError(
                "Photo IDs must be unique",
            )
        return value

    @field_validator(
        "patientComplaints",
    )
    @classmethod
    def normalize_optional_complaints(
        cls,
        value: str | None,
    ) -> str | None:
        if value is None:
            return None
        return value.strip() or None
