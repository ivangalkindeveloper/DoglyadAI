from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.application.service_dependencies import ServiceDependencies
from app.model.billing.billing_identity_response import BillingIdentityResponse
from app.model.billing.billing_recovery_request import BillingRecoveryRequest
from app.service.billing.subscription_service import SubscriptionService

router = APIRouter()


@router.post(
    "/recover",
    response_model=BillingIdentityResponse,
)
async def recover(
    body: BillingRecoveryRequest,
    service: Annotated[
        SubscriptionService,
        Depends(
            ServiceDependencies.subscriptions,
        ),
    ],
) -> BillingIdentityResponse:
    return await service.recover(
        body.recoveryKey,
    )
