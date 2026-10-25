from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class TemplateEditConfig(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True, strict=True)

    nameMaxLength: int = Field(gt=0)
    contentMaxLength: int = Field(gt=0)
