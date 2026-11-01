from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.model.non_blank_string import NonBlankString


class BillingCheckoutResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
    )

    id: UUID
    code: NonBlankString
    expiresAt: datetime
