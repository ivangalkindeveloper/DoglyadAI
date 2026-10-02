from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.model.ultrasound.us_voice_field_id import USVoiceFieldId


class USVoiceFieldProposal(BaseModel):
    model_config = ConfigDict(extra="forbid")

    fieldId: USVoiceFieldId
    value: str = Field(min_length=1)
    sourceQuote: str = Field(min_length=1)
