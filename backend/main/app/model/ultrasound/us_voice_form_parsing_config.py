from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class USVoiceFormParsingConfig(BaseModel):
    model_config = ConfigDict(extra="forbid")

    maxTokens: int = Field(gt=0, le=4096)
