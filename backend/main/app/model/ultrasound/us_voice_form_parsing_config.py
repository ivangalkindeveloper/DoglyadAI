from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.model.non_blank_string import NonBlankString


class USVoiceFormParsingConfig(BaseModel):
    model_config = ConfigDict(extra="forbid")

    modelId: NonBlankString = Field(min_length=1)
    maxTokens: int = Field(gt=0, le=4096)
