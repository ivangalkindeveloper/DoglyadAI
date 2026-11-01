from __future__ import annotations

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database.billing_base import BillingBase


class BillingCredentialDB(BillingBase):
    __tablename__ = "billing_credentials"

    token_hash: Mapped[str] = mapped_column(
        String(
            64,
        ),
        primary_key=True,
    )
    owner_id: Mapped[str] = mapped_column(
        ForeignKey(
            "billing_owners.id",
        ),
        index=True,
    )
