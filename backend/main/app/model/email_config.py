from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class EmailConfig(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    socket_timeout_seconds: float = Field(gt=0)
    max_attachment_bytes: int = Field(gt=0)
    max_total_attachment_bytes: int = Field(gt=0)
    max_attachments: int = Field(gt=0)
