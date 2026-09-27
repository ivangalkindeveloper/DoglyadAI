from __future__ import annotations

from pydantic import BaseModel


class USExaminationReadyMadeTemplateResponse(BaseModel):
    id: str
    examinationType: str
    title: str
    content: str
