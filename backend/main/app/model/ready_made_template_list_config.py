from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class ReadyMadeTemplateListConfig(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        strict=True,
    )

    searchMaxLength: int = Field(
        gt=0,
    )
