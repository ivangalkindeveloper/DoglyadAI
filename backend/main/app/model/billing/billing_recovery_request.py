from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class BillingRecoveryRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
    )

    recoveryKey: str = Field(
        min_length=32,
        max_length=128,
    )
