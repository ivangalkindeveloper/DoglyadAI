from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.model.http_client_config import HttpClientConfig


class BillingServiceConfig(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )

    provider: HttpClientConfig
    reconciliation_interval_seconds: int = Field(
        gt=0,
    )
    apple_reconciliation_interval_seconds: int = Field(
        gt=0,
    )
    checkout_ttl_seconds: int = Field(
        gt=0,
    )
    unknown_payment_retry_seconds: int = Field(
        gt=0,
        lt=86400,
    )
    pending_usage_timeout_seconds: int = Field(
        gt=0,
    )
    batch_size: int = Field(
        gt=0,
        le=500,
    )
