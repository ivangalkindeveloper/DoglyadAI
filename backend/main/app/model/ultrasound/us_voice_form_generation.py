from __future__ import annotations

import json

from pydantic import BaseModel, ConfigDict, Field

from app.model.ultrasound.us_voice_field_proposal import USVoiceFieldProposal


class USVoiceFormGeneration(BaseModel):
    model_config = ConfigDict(extra="forbid")

    # The eight form fields are the upper bound on useful proposals. Capping the
    # array in the generation grammar prevents repeated entries from exhausting
    # the model's token budget before it closes the JSON document.
    proposals: list[USVoiceFieldProposal] = Field(max_length=8)
    unmappedFindings: list[str] = Field(max_length=8)

    @classmethod
    def structured_output(cls) -> str:
        return json.dumps(cls.model_json_schema(), ensure_ascii=False, separators=(",", ":"))
