from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.model.billing.billing_auto_renewal_request import BillingAutoRenewalRequest
from app.model.billing.billing_status_response import BillingStatusResponse
from app.service.billing.subscription_service import SubscriptionService

router = APIRouter()


@router.post(
    "/auto_renewal",
    response_model=BillingStatusResponse | None,
)
async def auto_renewal(
    body: BillingAutoRenewalRequest,
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
) -> BillingStatusResponse | None:
    await service.set_auto_renewal(
        owner_id,
        body.isAutoRenewing,
    )
    return await service.status(
        owner_id,
    )
