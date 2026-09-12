from __future__ import annotations

import json
from typing import Any

from pydantic import BaseModel, Field, field_validator

from app.model.generation_image import GenerationImage


def _parse_structured_output(value: str) -> dict[str, Any]:
    try:
        schema = json.loads(value)
    except json.JSONDecodeError as error:
        raise ValueError("structuredOutput must contain valid JSON") from error
    if not isinstance(schema, dict):
        raise ValueError("structuredOutput must contain a JSON object")
    return schema


class GenerationRequest(BaseModel):
    """A model-agnostic generation request sent by the coordinating service."""

    modelId: str
    prompt: str
    systemPrompt: str | None = None
    structuredOutput: str | None = Field(default=None, min_length=2)
    images: list[GenerationImage] | None = None
    temperature: float | None = Field(default=None, ge=0.0, le=2.0)
    maxTokens: int | None = Field(default=None, gt=0, le=4096)

    @field_validator("structuredOutput")
    @classmethod
    def validate_structured_output(cls, value: str | None) -> str | None:
        if value is not None:
            _parse_structured_output(value)
        return value

    def structured_output_schema(self) -> dict[str, Any] | None:
        if self.structuredOutput is None:
            return None
        return _parse_structured_output(self.structuredOutput)
