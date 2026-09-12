from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.vllm_message import VLLMMessage


class VLLMChoice(BaseModel):
    model_config = ConfigDict(extra="ignore")

    message: VLLMMessage
    finish_reason: str | None = None
