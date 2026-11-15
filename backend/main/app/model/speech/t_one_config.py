from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class TOneConfig(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )

    cpu_threads: int = Field(
        default=4,
        ge=1,
        le=16,
    )
    max_waiting_requests: int = Field(
        default=2,
        ge=0,
        le=16,
    )
    queue_timeout_seconds: float = Field(
        default=10,
        gt=0,
        le=30,
    )
    operation_timeout_seconds: float = Field(
        default=120,
        gt=0,
        le=180,
    )
