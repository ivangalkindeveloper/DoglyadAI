from __future__ import annotations

from pydantic import BaseModel, Field


class NeuralModelSettings(BaseModel):
    selectedNeuralModelId: str | None = None
    isMarkdown: bool = Field(default=False)
    temperature: float | None = Field(default=None, ge=0.0, le=2.0)
    maxTokens: int | None = Field(default=None, gt=0, le=4096)
