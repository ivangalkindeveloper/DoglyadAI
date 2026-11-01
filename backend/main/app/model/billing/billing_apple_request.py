from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class BillingAppleRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
    )

    signedTransaction: str = Field(
        min_length=1,
        max_length=32768,
    )
