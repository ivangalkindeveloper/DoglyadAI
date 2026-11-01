from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.model.billing.billing_period import BillingPeriod
from app.model.billing.billing_price import BillingPrice
from app.model.non_blank_string import NonBlankString


class BillingProductResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
    )

    id: NonBlankString = Field(
        min_length=1,
    )
    period: BillingPeriod
    entitlement: NonBlankString
    price: BillingPrice
    title: NonBlankString
    priceTemplate: NonBlankString

    @field_validator(
        "priceTemplate",
    )
    @classmethod
    def validate_price_template(
        cls,
        value: str,
    ) -> str:
        remaining = value.replace(
            "{price}",
            "",
        )
        if (
            value.count(
                "{price}",
            )
            != 1
            or "{" in remaining
            or "}" in remaining
        ):
            raise ValueError(
                "A price template must contain exactly one {price} placeholder",
            )
        return value
