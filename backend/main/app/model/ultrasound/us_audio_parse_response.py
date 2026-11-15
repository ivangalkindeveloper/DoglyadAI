from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.non_blank_string import NonBlankString
from app.model.ultrasound.us_voice_form_parse_response import USVoiceFormParseResponse


class USAudioParseResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )

    transcript: NonBlankString
    result: USVoiceFormParseResponse
