from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.billing.billing_payment_response import BillingPaymentResponse
from app.model.billing.billing_price import BillingPrice
from app.model.non_blank_string import NonBlankString


class BillingPreparePaymentResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )

    payment: BillingPaymentResponse
    shopId: NonBlankString
    clientApplicationKey: NonBlankString
    shopName: NonBlankString
    description: NonBlankString
    termsVersion: NonBlankString
    price: BillingPrice
