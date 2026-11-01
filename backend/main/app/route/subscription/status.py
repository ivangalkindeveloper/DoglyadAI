from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.model.billing.billing_status_response import BillingStatusResponse
from app.service.billing.subscription_service import SubscriptionService

router = APIRouter()


@router.get(
    "/status",
    response_model=BillingStatusResponse | None,
)
async def status(
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
    return await service.status(
        owner_id,
    )
