from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.model.non_blank_string import NonBlankString


class BillingIdentityResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
    )

    ownerId: UUID
    accessToken: NonBlankString = Field(
        min_length=32,
    )
    recoveryKey: NonBlankString | None = None
