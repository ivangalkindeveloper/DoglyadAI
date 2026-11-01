from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.billing.billing_product_response import BillingProductResponse
from app.model.billing.billing_tier_response import BillingTierResponse


class BillingProductsResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )

    products: list[BillingProductResponse]
    tiers: list[BillingTierResponse]
