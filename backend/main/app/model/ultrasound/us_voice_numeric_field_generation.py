from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.model.ultrasound.us_voice_field_accuracy import USVoiceFieldAccuracy
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId


class USVoiceNumericFieldGeneration(BaseModel):
    model_config = ConfigDict(extra="forbid")

    field_id: Literal[USVoiceFieldId.PATIENT_HEIGHT_CM, USVoiceFieldId.PATIENT_WEIGHT_KG]
    value: float
    evidence: str = Field(min_length=1)
    accuracy: USVoiceFieldAccuracy

    @field_validator("value", mode="before")
    @classmethod
    def require_json_number(cls, value: object) -> object:
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ValueError("A measurement must be a JSON number")
        return value
