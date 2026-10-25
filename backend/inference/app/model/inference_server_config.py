from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.model.generation_config import GenerationConfig
from app.model.http_client_config import HttpClientConfig


class InferenceServerConfig(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    vllm: HttpClientConfig
    generation: GenerationConfig
    default_max_body_bytes: int = Field(gt=0)
