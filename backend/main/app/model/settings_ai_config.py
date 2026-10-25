from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class SettingsAIConfig(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True, strict=True)

    temperatureMaxLength: int = Field(gt=0)
    maxTokensMaxLength: int = Field(gt=0)
