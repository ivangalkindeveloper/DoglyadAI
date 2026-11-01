from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.non_blank_string import NonBlankString


class BillingRecoveryResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
    )

    recoveryKey: NonBlankString
