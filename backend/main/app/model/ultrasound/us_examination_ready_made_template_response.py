from __future__ import annotations

from pydantic import BaseModel

from app.model.non_blank_string import NonBlankString


class USExaminationReadyMadeTemplateResponse(BaseModel):
    id: NonBlankString
    examinationType: NonBlankString
    title: NonBlankString
    content: NonBlankString
