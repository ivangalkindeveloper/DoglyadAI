from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class SpeechTranscriptResponse(BaseModel):
    model_config = ConfigDict(
        str_strip_whitespace=True,
    )

    transcript: str = Field(
        min_length=1,
    )
