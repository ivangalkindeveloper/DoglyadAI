from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, ConfigDict


class BillingCheckPaymentRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )

    paymentId: UUID
    isAbandoned: bool = False
