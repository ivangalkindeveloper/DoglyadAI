from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.model.ultrasound.us_voice_field_accuracy import USVoiceFieldAccuracy
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId


class USVoiceBirthDateFieldGeneration(BaseModel):
    model_config = ConfigDict(extra="forbid")

    field_id: Literal[USVoiceFieldId.PATIENT_DATE_OF_BIRTH]
    value: str = Field(pattern=r"^\d{4}-\d{2}-\d{2}$")
    evidence: str = Field(min_length=1)
    accuracy: USVoiceFieldAccuracy
