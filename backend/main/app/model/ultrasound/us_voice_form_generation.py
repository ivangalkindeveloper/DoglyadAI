from __future__ import annotations

import json

from pydantic import BaseModel, ConfigDict

from app.model.ultrasound.us_voice_field_proposal import USVoiceFieldProposal


class USVoiceFormGeneration(BaseModel):
    model_config = ConfigDict(extra="forbid")

    proposals: list[USVoiceFieldProposal]
    unmappedFindings: list[str]

    @classmethod
    def structured_output(cls) -> str:
        return json.dumps(cls.model_json_schema(), ensure_ascii=False, separators=(",", ":"))
