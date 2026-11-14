from __future__ import annotations

from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.model.billing.billing_catalog import BillingCatalog
from app.model.billing.billing_product_response import BillingProductResponse
from app.model.billing.billing_products_response import BillingProductsResponse
from app.model.billing.billing_tier_response import BillingTierResponse


class BillingCatalogResponseService:
    def __init__(
        self,
    ) -> None:
        pass

    @staticmethod
    def make(
        catalog: BillingCatalog,
        configuration: Configuration,
        language: LanguageCode,
    ) -> BillingProductsResponse:
        return BillingProductsResponse(
            tiers=[
                BillingTierResponse(
                    id=tier.id,
                    title=configuration.text(
                        language,
                        tier.titleLocaleKey,
                    ),
                    features=[
                        configuration.text(
                            language,
                            key,
                        )
                        for key in tier.featureLocaleKeys
                    ],
                )
                for tier in catalog.tiers
            ],
            products=[
                BillingProductResponse(
                    id=plan.id,
                    period=plan.period,
                    entitlement=plan.entitlement,
                    price=plan.price,
                    title=configuration.text(
                        language,
                        plan.titleLocaleKey,
                    ),
                    priceTemplate=configuration.text(
                        language,
                        plan.priceTemplateLocaleKey,
                    ),
                )
                for plan in catalog.products
            ],
        )
