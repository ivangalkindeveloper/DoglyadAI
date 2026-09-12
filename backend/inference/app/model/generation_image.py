from __future__ import annotations

from pydantic import BaseModel


class GenerationImage(BaseModel):
    data: str
