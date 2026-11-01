from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.service.billing.subscription_service import SubscriptionService

router = APIRouter()


@router.post(
    "/cancel",
    status_code=204,
)
async def cancel(
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
) -> None:
    await service.cancel(
        owner_id,
    )
