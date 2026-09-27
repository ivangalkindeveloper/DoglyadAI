from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class USExaminationType(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    titleLocaleKey: str
    contextualStringsLocaleKey: str
