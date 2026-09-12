from __future__ import annotations

from pydantic import BaseModel


class GenerationResponse(BaseModel):
    modelId: str
    response: str
