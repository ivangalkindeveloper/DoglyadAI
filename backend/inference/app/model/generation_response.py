from __future__ import annotations

from pydantic import BaseModel

from app.model.non_blank_string import NonBlankString


class GenerationResponse(BaseModel):
    modelId: NonBlankString
    response: NonBlankString
