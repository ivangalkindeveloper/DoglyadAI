from __future__ import annotations

from pydantic import BaseModel


class USExaminationTypeResponse(BaseModel):
    id: str
    title: str
    contextualStrings: list[str]
