from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.model.billing.billing_product_config import BillingProductConfig
from app.model.non_blank_string import NonBlankString


class BillingTierConfig(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
    )

    id: Literal["base", "pro"]
    titleLocaleKey: NonBlankString
    featureLocaleKeys: list[NonBlankString] = Field(
        min_length=1,
    )
    products: list[BillingProductConfig]
