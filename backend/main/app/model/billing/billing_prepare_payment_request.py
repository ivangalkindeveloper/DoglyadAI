from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.model.non_blank_string import NonBlankString


class BillingPreparePaymentRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )

    planId: NonBlankString = Field(
        max_length=128,
    )
