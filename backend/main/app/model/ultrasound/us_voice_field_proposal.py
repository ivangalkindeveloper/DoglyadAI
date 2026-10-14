from __future__ import annotations

from pydantic import BaseModel, ConfigDict, field_validator

from app.model.non_blank_string import NonBlankString
from app.model.ultrasound.us_voice_field_accuracy import USVoiceFieldAccuracy
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId


class USVoiceFieldProposal(BaseModel):
    model_config = ConfigDict(extra="forbid")

    fieldId: USVoiceFieldId
    value: NonBlankString | float
    evidence: NonBlankString
    accuracy: USVoiceFieldAccuracy

    @field_validator("value", mode="before")
    @classmethod
    def reject_boolean_value(cls, value: object) -> object:
        if isinstance(value, bool):
            raise ValueError("A field value must be a string or number")
        return value
