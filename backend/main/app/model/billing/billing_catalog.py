from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.model.billing.billing_product_config import BillingProductConfig
from app.model.billing.billing_tier_config import BillingTierConfig
from app.model.non_blank_string import NonBlankString


class BillingCatalog(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
    )

    termsVersion: NonBlankString = Field(
        min_length=1,
    )
    products: list[BillingProductConfig]
    tiers: list[BillingTierConfig]

    @model_validator(
        mode="after",
    )
    def validate_identifiers(
        self,
    ) -> BillingCatalog:
        identifiers = [product.id for product in self.products]
        tier_ids = [tier.id for tier in self.tiers]
        if len(
            tier_ids,
        ) != len(
            set(
                tier_ids,
            ),
        ):
            raise ValueError(
                "Billing tier identifiers must be unique",
            )
        if any(
            (product.entitlement not in tier_ids for product in self.products),
        ):
            raise ValueError(
                "Every billing product must reference a configured tier",
            )
        if len(
            identifiers,
        ) != len(
            set(
                identifiers,
            ),
        ):
            raise ValueError(
                "Billing product identifiers must be unique",
            )
        return self
