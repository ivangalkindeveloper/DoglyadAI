from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class BillingAutoRenewalRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )
    isAutoRenewing: bool
