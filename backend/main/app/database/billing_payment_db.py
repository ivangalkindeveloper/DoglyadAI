from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database.billing_base import BillingBase


class BillingPaymentDB(BillingBase):
    __tablename__ = "billing_payments"

    __table_args__ = (
        UniqueConstraint(
            "subscription_id",
            "period_key",
        ),
    )

    id: Mapped[str] = mapped_column(
        String(
            36,
        ),
        primary_key=True,
    )
    owner_id: Mapped[str] = mapped_column(
        ForeignKey(
            "billing_owners.id",
        ),
        index=True,
    )
    subscription_id: Mapped[str | None] = mapped_column(
        ForeignKey(
            "billing_subscriptions.id",
        ),
    )
    period_key: Mapped[str | None] = mapped_column(
        String(
            64,
        ),
    )
    plan_id: Mapped[str] = mapped_column(
        String(
            128,
        ),
    )
    entitlement: Mapped[str] = mapped_column(
        String(
            16,
        ),
    )
    amount_minor: Mapped[int] = mapped_column(
        Integer,
    )
    interval_months: Mapped[int] = mapped_column(
        Integer,
        default=1,
    )
    interval_days: Mapped[int] = mapped_column(
        Integer,
        default=0,
        server_default="0",
    )
    currency: Mapped[str] = mapped_column(
        String(
            3,
        ),
    )
    status: Mapped[str] = mapped_column(
        String(
            24,
        ),
        index=True,
    )
    channel: Mapped[str] = mapped_column(
        String(
            16,
        ),
        default="redirect",
        server_default="redirect",
    )
    payment_token_hash: Mapped[str | None] = mapped_column(
        String(
            64,
        ),
    )
    payment_method_type: Mapped[str | None] = mapped_column(
        String(
            32,
        ),
    )
    terms_version: Mapped[str | None] = mapped_column(
        String(
            128,
        ),
    )
    consent_at: Mapped[datetime | None] = mapped_column(
        DateTime(
            timezone=True,
        ),
    )
    provider_id: Mapped[str | None] = mapped_column(
        String(
            128,
        ),
        unique=True,
    )
    submitted_at: Mapped[datetime | None] = mapped_column(
        DateTime(
            timezone=True,
        ),
    )
    renewal_payment_method_id: Mapped[str | None] = mapped_column(
        String(
            128,
        ),
    )
    refunded_amount_minor: Mapped[int] = mapped_column(
        Integer,
        default=0,
        server_default="0",
    )
    reconciliation_attempted_at: Mapped[datetime | None] = mapped_column(
        DateTime(
            timezone=True,
        ),
        index=True,
    )
    confirmation_url: Mapped[str | None] = mapped_column(
        Text,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
    )
    period_until: Mapped[datetime | None] = mapped_column(
        DateTime(
            timezone=True,
        ),
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(
            timezone=True,
        ),
    )
    is_receipt_pending: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
    )
