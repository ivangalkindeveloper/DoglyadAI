from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.model.ultrasound.us_voice_field_accuracy import USVoiceFieldAccuracy
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId


class USVoiceReadinessFieldGeneration(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )
    field_id: Literal[USVoiceFieldId.IS_PATIENT_PREPARED_FOR_EXAMINATION]
    value: Literal["true", "false"]
    evidence: str = Field(
        min_length=1,
    )
    accuracy: USVoiceFieldAccuracy
