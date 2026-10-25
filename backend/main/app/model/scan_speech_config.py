from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class ScanSpeechConfig(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True, strict=True)

    transcriptMaxLength: int = Field(gt=0)
