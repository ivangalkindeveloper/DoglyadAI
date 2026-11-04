from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, LargeBinary, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database.billing_base import BillingBase


class ReportGenerationDB(BillingBase):
    __tablename__ = "report_generations"
    __table_args__ = (
        UniqueConstraint(
            "owner_id",
            "request_id",
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
    request_id: Mapped[str] = mapped_column(
        String(
            36,
        ),
    )
    request_digest: Mapped[str] = mapped_column(
        String(
            64,
        ),
    )
    status: Mapped[str] = mapped_column(
        String(
            16,
        ),
        index=True,
    )
    model_id: Mapped[str] = mapped_column(
        String(
            256,
        ),
    )
    sequence: Mapped[int] = mapped_column(
        Integer,
        default=0,
    )
    payload: Mapped[bytes | None] = mapped_column(
        LargeBinary,
        nullable=True,
    )
    snapshot: Mapped[bytes] = mapped_column(
        LargeBinary,
    )
    error_code: Mapped[str | None] = mapped_column(
        String(
            80,
        ),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
        index=True,
    )
    deadline_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
        index=True,
    )
