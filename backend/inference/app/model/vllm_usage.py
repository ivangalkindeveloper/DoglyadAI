from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class VLLMUsage(BaseModel):
    model_config = ConfigDict(extra="ignore")

    prompt_tokens: int = 0
    completion_tokens: int = 0
