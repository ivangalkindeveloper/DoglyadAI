from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.model.non_blank_string import NonBlankString


class BillingTokenizePaymentRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )

    paymentId: UUID
    paymentToken: NonBlankString = Field(
        max_length=2048,
        repr=False,
    )
    termsVersion: NonBlankString = Field(
        max_length=128,
    )
    isAutoRenewalAccepted: bool
