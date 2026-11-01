from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.application.service_dependencies import ServiceDependencies
from app.core.localization.language_code import LanguageCode
from app.core.localization.localization_dependencies import LocalizationDependencies
from app.model.billing.billing_products_response import BillingProductsResponse
from app.service.billing.subscription_service import SubscriptionService

router = APIRouter()


@router.get(
    "/plans",
    response_model=BillingProductsResponse,
)
async def plans(
    language: Annotated[
        LanguageCode,
        Depends(
            LocalizationDependencies.language,
        ),
    ],
    service: Annotated[
        SubscriptionService,
        Depends(
            ServiceDependencies.subscriptions,
        ),
    ],
) -> BillingProductsResponse:
    return service.plans(
        language,
    )
