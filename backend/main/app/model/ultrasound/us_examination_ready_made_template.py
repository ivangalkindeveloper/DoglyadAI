from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.non_blank_string import NonBlankString


class USExaminationReadyMadeTemplate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: NonBlankString
    examinationType: NonBlankString
    titleLocaleKey: NonBlankString
    contentLocaleKey: NonBlankString
