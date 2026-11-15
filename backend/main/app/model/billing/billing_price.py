from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class BillingPrice(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )

    amountMinor: int = Field(
        gt=0,
    )
    oldAmountMinor: int = Field(
        gt=0,
    )
    currencyIso2Code: Literal["RUB"]

    @model_validator(
        mode="after",
    )
    def validate_old_amount(
        self,
    ) -> BillingPrice:
        if self.oldAmountMinor <= self.amountMinor:
            raise ValueError(
                "oldAmountMinor must be greater than amountMinor",
            )
        return self
