from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.model.non_blank_string import NonBlankString


class BillingTierResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
    )

    id: Literal["base", "pro"]
    title: NonBlankString
    features: list[NonBlankString] = Field(
        min_length=1,
    )
