from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class ScanConfig(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        strict=True,
    )

    examinationNumberMaxLength: int = Field(
        gt=0,
    )
    patientNameMaxLength: int = Field(
        gt=0,
    )
    patientHeightCMMaxLength: int = Field(
        gt=0,
    )
    patientWeightKGMaxLength: int = Field(
        gt=0,
    )
    patientComplaintsMaxLength: int = Field(
        gt=0,
    )
    examinationDescriptionMaxLength: int = Field(
        gt=0,
    )
