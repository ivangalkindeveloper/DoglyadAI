from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.model.non_blank_string import NonBlankString


class BillingStatusResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
    )

    type: NonBlankString
    source: str | None = None
    planId: NonBlankString
    expiresAt: datetime | None = None
    isAutoRenewing: bool = False
    availableCountPerDay: int = Field(
        ge=0,
    )
