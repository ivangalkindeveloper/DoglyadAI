from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.model.ultrasound.us_voice_field_proposal import USVoiceFieldProposal


class USVoiceFormParseResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    proposals: list[USVoiceFieldProposal]
    rejectedFieldIds: list[USVoiceFieldId]
    unmappedFindings: list[str]
