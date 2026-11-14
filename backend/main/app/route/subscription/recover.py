from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.application.service_dependencies import ServiceDependencies
from app.model.billing.billing_recovered_access_response import BillingRecoveredAccessResponse
from app.model.billing.billing_recovery_request import BillingRecoveryRequest
from app.service.billing.subscription_service import SubscriptionService

router = APIRouter()


@router.post(
    "/recover",
    response_model=BillingRecoveredAccessResponse,
)
async def recover(
    body: BillingRecoveryRequest,
    service: Annotated[
        SubscriptionService,
        Depends(
            ServiceDependencies.subscriptions,
        ),
    ],
) -> BillingRecoveredAccessResponse:
    identity = await service.recover(
        body.recoveryKey,
    )
    return BillingRecoveredAccessResponse(
        identity=identity,
        subscription=await service.status(
            str(
                identity.ownerId,
            ),
        ),
    )
