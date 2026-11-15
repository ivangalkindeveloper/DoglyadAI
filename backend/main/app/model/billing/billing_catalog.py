from __future__ import annotations

from pydantic import ConfigDict, RootModel, model_validator

from app.model.billing.billing_tier_config import BillingTierConfig


class BillingCatalog(RootModel[list[BillingTierConfig]]):
    model_config = ConfigDict(
        frozen=True,
    )

    @model_validator(
        mode="after",
    )
    def validate_identifiers(
        self,
    ) -> BillingCatalog:
        identifiers = [product.id for tier in self.root for product in tier.products]
        tier_ids = [tier.id for tier in self.root]
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
