from __future__ import annotations

from pydantic import BaseModel

from app.model.non_blank_string import NonBlankString


class USExaminationTypeResponse(BaseModel):
    id: NonBlankString
    title: NonBlankString
    contextualStrings: list[str]
