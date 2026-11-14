from __future__ import annotations

from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.model.non_blank_string import NonBlankString


class BillingPaymentResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )

    id: UUID
    planId: NonBlankString
    status: Literal["created", "pending", "succeeded", "canceled", "refunded", "needsReview"]
    confirmationUrl: NonBlankString | None = None
    paymentMethodType: NonBlankString | None = None
    recoveryKey: NonBlankString | None = None
