from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.model.billing.billing_recovery_response import BillingRecoveryResponse
from app.service.billing.subscription_service import SubscriptionService

router = APIRouter()


@router.post(
    "/recovery_key",
    response_model=BillingRecoveryResponse,
)
async def recovery_key(
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
) -> BillingRecoveryResponse:
    return BillingRecoveryResponse(
        recoveryKey=await service.recovery_key(
            owner_id,
        ),
    )
