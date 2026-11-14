from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.billing.billing_payment_response import BillingPaymentResponse
from app.model.non_blank_string import NonBlankString


class BillingPreparePaymentResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )
    payment: BillingPaymentResponse
    checkoutUrl: NonBlankString | None
