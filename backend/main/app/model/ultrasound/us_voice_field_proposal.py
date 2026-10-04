from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.model.ultrasound.us_voice_field_accuracy import USVoiceFieldAccuracy
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId


class USVoiceFieldProposal(BaseModel):
    model_config = ConfigDict(extra="forbid")

    field_id: USVoiceFieldId
    value: str | float
    evidence: str = Field(min_length=1)
    accuracy: USVoiceFieldAccuracy

    @field_validator("value", mode="before")
    @classmethod
    def reject_boolean_value(cls, value: object) -> object:
        if isinstance(value, bool):
            raise ValueError("A field value must be a string or number")
        return value
