from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class USExaminationReadyMadeTemplate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    examinationType: str
    titleLocaleKey: str
    contentLocaleKey: str
