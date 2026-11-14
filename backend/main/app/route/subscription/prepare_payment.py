from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.core.localization.language_code import LanguageCode
from app.core.localization.localization_dependencies import LocalizationDependencies
from app.model.billing.billing_prepare_payment_request import BillingPreparePaymentRequest
from app.model.billing.billing_prepare_payment_response import BillingPreparePaymentResponse
from app.service.billing.checkout_payment_service import CheckoutPaymentService

router = APIRouter()


@router.post(
    "/prepare_payment",
    response_model=BillingPreparePaymentResponse,
)
async def prepare_payment(
    body: BillingPreparePaymentRequest,
    service: Annotated[
        CheckoutPaymentService,
        Depends(
            ServiceDependencies.checkout_payments,
        ),
    ],
    owner_id: Annotated[
        str,
        Depends(
            BillingDependencies.owner,
        ),
    ],
    language: Annotated[
        LanguageCode,
        Depends(
            LocalizationDependencies.language,
        ),
    ],
) -> BillingPreparePaymentResponse:
    return await service.prepare(
        owner_id,
        body.planId,
        language,
        is_auto_renewing=body.isAutoRenewing,
        expected_price=body.price,
    )
