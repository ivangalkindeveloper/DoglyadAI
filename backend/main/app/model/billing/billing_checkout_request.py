from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class BillingCheckoutRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
    )

    planId: str = Field(
        min_length=1,
        max_length=128,
    )
