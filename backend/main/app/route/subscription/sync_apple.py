from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.model.billing.billing_apple_request import BillingAppleRequest
from app.model.billing.billing_identity_response import BillingIdentityResponse
from app.service.billing.subscription_service import SubscriptionService

router = APIRouter()


@router.post(
    "/sync_apple",
    response_model=BillingIdentityResponse | None,
)
async def sync_apple(
    body: BillingAppleRequest,
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
) -> BillingIdentityResponse | None:
    return await service.sync_apple(
        owner_id,
        body.signedTransaction,
    )
