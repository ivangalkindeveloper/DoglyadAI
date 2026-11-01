from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.application.service_dependencies import ServiceDependencies
from app.model.billing.billing_identity_response import BillingIdentityResponse
from app.service.billing.subscription_service import SubscriptionService

router = APIRouter()


@router.post(
    "/register",
    response_model=BillingIdentityResponse,
)
async def register(
    service: Annotated[
        SubscriptionService,
        Depends(
            ServiceDependencies.subscriptions,
        ),
    ],
) -> BillingIdentityResponse:
    return await service.register()
