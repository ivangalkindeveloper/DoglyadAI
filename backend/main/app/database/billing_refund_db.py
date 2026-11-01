from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database.billing_base import BillingBase


class BillingRefundDB(BillingBase):
    __tablename__ = "billing_refunds"

    id: Mapped[str] = mapped_column(
        String(
            128,
        ),
        primary_key=True,
    )
    payment_id: Mapped[str] = mapped_column(
        ForeignKey(
            "billing_payments.id",
        ),
        index=True,
    )
    amount_minor: Mapped[int] = mapped_column(
        Integer,
    )
    currency: Mapped[str] = mapped_column(
        String(
            3,
        ),
    )
    status: Mapped[str] = mapped_column(
        String(
            16,
        ),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
    )
