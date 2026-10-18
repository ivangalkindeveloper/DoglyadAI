from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.model.ultrasound.us_voice_field_accuracy import USVoiceFieldAccuracy
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId


class USVoiceGenderFieldGeneration(BaseModel):
    model_config = ConfigDict(extra="forbid")

    field_id: Literal[USVoiceFieldId.PATIENT_GENDER]
    value: Literal["male", "female"]
    evidence: str = Field(min_length=1)
    accuracy: USVoiceFieldAccuracy
