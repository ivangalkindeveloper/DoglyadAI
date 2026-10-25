from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class GenerationConfig(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    max_body_bytes: int = Field(gt=0)
    max_images: int = Field(gt=0)
    max_image_bytes: int = Field(gt=0)
    max_concurrent_requests: int = Field(gt=0)
    max_waiting_requests: int = Field(ge=0)
    queue_timeout_seconds: float = Field(gt=0)
    retry_after_seconds: int = Field(gt=0)
