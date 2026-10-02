from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field, field_validator


class USVoiceFormParseRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    usExaminationTypeId: str = Field(min_length=1, max_length=128)
    transcript: str = Field(min_length=1, max_length=8000)

    @field_validator("transcript")
    @classmethod
    def reject_blank_transcript(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Transcript must contain speech")
        return value
