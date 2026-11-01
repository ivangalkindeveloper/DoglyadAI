from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database.billing_base import BillingBase


class BillingCheckoutDB(BillingBase):
    __tablename__ = "billing_checkouts"

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
    plan_id: Mapped[str] = mapped_column(
        String(
            128,
        ),
    )
    code_hash: Mapped[str] = mapped_column(
        String(
            64,
        ),
        unique=True,
    )
    browser_hash: Mapped[str | None] = mapped_column(
        String(
            64,
        ),
        unique=True,
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
    )
    payment_id: Mapped[str | None] = mapped_column(
        ForeignKey(
            "billing_payments.id",
        ),
    )
    apple_token: Mapped[str | None] = mapped_column(
        Text,
    )
    is_auto_renewal_accepted: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
    )
    terms_version: Mapped[str | None] = mapped_column(
        String(
            64,
        ),
    )
