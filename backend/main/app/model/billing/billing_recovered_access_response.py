from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.billing.billing_identity_response import BillingIdentityResponse
from app.model.billing.billing_status_response import BillingStatusResponse


class BillingRecoveredAccessResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )
    identity: BillingIdentityResponse
    subscription: BillingStatusResponse | None
