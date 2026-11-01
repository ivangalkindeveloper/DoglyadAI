from __future__ import annotations

from typing import Literal

from pydantic import BaseModel


class BillingWebhookResponse(BaseModel):
    status: Literal["accepted", "ignored"]
