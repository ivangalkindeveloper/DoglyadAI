from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.vllm_choice import VLLMChoice
from app.model.vllm_usage import VLLMUsage


class VLLMChatCompletion(BaseModel):
    """The `/v1/chat/completions` payload of the local vLLM OpenAI-compatible server."""

    model_config = ConfigDict(extra="ignore")

    choices: list[VLLMChoice]
    usage: VLLMUsage | None = None

    def value(self) -> str:
        if not self.choices:
            raise ValueError("vLLM response has empty choices")
        content = self.choices[0].message.content
        if not content:
            raise ValueError("vLLM response has empty message content")
        text = content.strip()
        if not text:
            raise ValueError("vLLM response content contains no text")
        return text
