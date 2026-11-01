from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.model.billing.billing_period import BillingPeriod
from app.model.billing.billing_price import BillingPrice
from app.model.non_blank_string import NonBlankString


class BillingProductConfig(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
    )

    id: NonBlankString = Field(
        min_length=1,
        max_length=128,
    )
    period: BillingPeriod
    entitlement: Literal["base", "pro"]
    price: BillingPrice
    titleLocaleKey: NonBlankString
    priceTemplateLocaleKey: NonBlankString
