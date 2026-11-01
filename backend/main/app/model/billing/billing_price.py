from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class BillingPrice(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )

    amountMinor: int = Field(
        gt=0,
    )
    currencyIso2Code: Literal["RUB"]
