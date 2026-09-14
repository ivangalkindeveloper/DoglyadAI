from __future__ import annotations

from pydantic import BaseModel


class USExaminationReadyMadeTemplate(BaseModel):
    id: str
    examinationType: str
    title: dict[str, str]
    content: dict[str, str]
