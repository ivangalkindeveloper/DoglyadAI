from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.model.billing.billing_checkout_request import BillingCheckoutRequest
from app.model.billing.billing_checkout_response import BillingCheckoutResponse
from app.service.billing.subscription_service import SubscriptionService

router = APIRouter()


@router.post(
    "/checkout",
    response_model=BillingCheckoutResponse,
)
async def checkout(
    body: BillingCheckoutRequest,
    service: Annotated[
        SubscriptionService,
        Depends(
            ServiceDependencies.subscriptions,
        ),
    ],
    owner_id: Annotated[
        str,
        Depends(
            BillingDependencies.owner,
        ),
    ],
) -> BillingCheckoutResponse:
    return await service.create_checkout(
        owner_id,
        body.planId,
    )
