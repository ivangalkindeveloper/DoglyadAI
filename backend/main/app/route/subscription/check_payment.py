from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.model.billing.billing_check_payment_request import BillingCheckPaymentRequest
from app.model.billing.billing_payment_response import BillingPaymentResponse
from app.service.billing.sdk_payment_service import SDKPaymentService

router = APIRouter()


@router.post(
    "/check_payment",
    response_model=BillingPaymentResponse,
)
async def check_payment(
    body: BillingCheckPaymentRequest,
    service: Annotated[
        SDKPaymentService,
        Depends(
            ServiceDependencies.sdk_payments,
        ),
    ],
    owner_id: Annotated[
        str,
        Depends(
            BillingDependencies.owner,
        ),
    ],
) -> BillingPaymentResponse:
    return await service.check(
        owner_id,
        str(
            body.paymentId,
        ),
        is_abandoned=body.isAbandoned,
    )
