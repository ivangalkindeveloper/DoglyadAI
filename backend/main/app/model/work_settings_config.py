from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class WorkSettingsConfig(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        strict=True,
    )

    emailMaxLength: int = Field(
        gt=0,
    )
