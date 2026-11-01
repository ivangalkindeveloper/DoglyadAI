from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class EndpointConfig(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )

    requests_per_minute: int = Field(
        gt=0,
    )
    max_body_bytes: int = Field(
        gt=0,
    )
