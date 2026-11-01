from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Index, Integer, String, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database.billing_base import BillingBase


class BillingSubscriptionDB(BillingBase):
    __tablename__ = "billing_subscriptions"

    __table_args__ = (
        CheckConstraint(
            "(source = 'apple' AND apple_environment IS NOT NULL "
            "AND apple_environment IN ('Production', 'Sandbox')) "
            "OR (source = 'yookassa' AND apple_environment IS NULL)",
            name="ck_billing_subscriptions_apple_environment",
        ),
        Index(
            "uq_billing_subscriptions_apple_transaction",
            "apple_environment",
            "external_id",
            unique=True,
            postgresql_where=text(
                "source = 'apple'",
            ),
            sqlite_where=text(
                "source = 'apple'",
            ),
        ),
        Index(
            "uq_billing_subscriptions_yookassa_transaction",
            "external_id",
            unique=True,
            postgresql_where=text(
                "source = 'yookassa'",
            ),
            sqlite_where=text(
                "source = 'yookassa'",
            ),
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
    source: Mapped[str] = mapped_column(
        String(
            16,
        ),
    )
    apple_environment: Mapped[str | None] = mapped_column(
        String(
            16,
        ),
    )
    external_id: Mapped[str] = mapped_column(
        String(
            128,
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
    paid_until: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
        index=True,
    )
    is_revoked: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
    )
    is_auto_renewing: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
    )
    payment_method_id: Mapped[str | None] = mapped_column(
        String(
            128,
        ),
    )
    amount_minor: Mapped[int] = mapped_column(
        Integer,
        default=0,
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
        default="RUB",
    )
    next_charge_at: Mapped[datetime | None] = mapped_column(
        DateTime(
            timezone=True,
        ),
        index=True,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
    )
