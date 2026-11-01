from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database.billing_base import BillingBase


class BillingUsageDB(BillingBase):
    __tablename__ = "billing_usage"

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
    day: Mapped[str] = mapped_column(
        String(
            10,
        ),
        index=True,
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
