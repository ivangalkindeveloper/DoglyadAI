from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.model.ultrasound.us_voice_field_accuracy import USVoiceFieldAccuracy
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId


class USVoiceTextFieldGeneration(BaseModel):
    model_config = ConfigDict(extra="forbid")

    field_id: Literal[
        USVoiceFieldId.EXAMINATION_NUMBER,
        USVoiceFieldId.PATIENT_NAME,
        USVoiceFieldId.PATIENT_GENDER,
        USVoiceFieldId.PATIENT_DATE_OF_BIRTH,
        USVoiceFieldId.PATIENT_COMPLAINTS,
        USVoiceFieldId.EXAMINATION_DESCRIPTION,
    ]
    value: str
    evidence: str = Field(min_length=1)
    accuracy: USVoiceFieldAccuracy
