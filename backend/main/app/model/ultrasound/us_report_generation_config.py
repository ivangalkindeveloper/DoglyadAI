from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class USReportGenerationConfig(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )
    retention_seconds: int = Field(
        default=43200,
        ge=300,
    )
    queue_timeout_seconds: float = Field(
        default=30,
        gt=0,
    )
    worker_concurrency: int = Field(
        default=12,
        ge=1,
        le=64,
    )
    poll_interval_seconds: float = Field(
        default=0.25,
        gt=0,
    )
    preview_interval_seconds: float = Field(
        default=0.15,
        gt=0,
    )
    heartbeat_seconds: float = Field(
        default=10,
        gt=0,
    )
    max_pending_per_owner: int = Field(
        default=2,
        ge=1,
    )
    max_response_bytes: int = Field(
        default=4194304,
        gt=0,
    )
    repetition_penalty: float = Field(
        default=1.05,
        ge=1.0,
        le=2.0,
    )
