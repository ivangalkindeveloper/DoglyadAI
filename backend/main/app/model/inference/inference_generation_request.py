from __future__ import annotations

from pydantic import BaseModel, Field

from app.model.inference.inference_generation_image import InferenceGenerationImage


class InferenceGenerationRequest(BaseModel):
    """Request contract sent from the main backend to an inference service."""

    modelId: str
    prompt: str
    systemPrompt: str | None = None
    structuredOutput: str | None = None
    images: list[InferenceGenerationImage] | None = None
    temperature: float | None = Field(default=None, ge=0.0, le=2.0)
    maxTokens: int | None = Field(default=None, gt=0, le=4096)
