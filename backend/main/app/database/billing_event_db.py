from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database.billing_base import BillingBase


class BillingEventDB(BillingBase):
    __tablename__ = "billing_events"

    id: Mapped[str] = mapped_column(
        String(
            256,
        ),
        primary_key=True,
    )
    source: Mapped[str] = mapped_column(
        String(
            16,
        ),
    )
    received_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
    )
