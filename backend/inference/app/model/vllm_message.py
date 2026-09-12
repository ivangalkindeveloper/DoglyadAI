from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class VLLMMessage(BaseModel):
    model_config = ConfigDict(extra="ignore")

    content: str | None = None
