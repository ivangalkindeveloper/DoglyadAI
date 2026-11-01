from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database.billing_base import BillingBase


class BillingOwnerDB(BillingBase):
    __tablename__ = "billing_owners"

    id: Mapped[str] = mapped_column(
        String(
            36,
        ),
        primary_key=True,
    )
    recovery_hash: Mapped[str | None] = mapped_column(
        String(
            64,
        ),
        unique=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
    )
