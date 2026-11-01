from __future__ import annotations

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine

from app.database.billing_owner_db import BillingOwnerDB
from app.error.billing_access_denied_error import BillingAccessDeniedError


class BillingDatabase:
    def __init__(
        self,
        url: str,
    ) -> None:
        self.engine: AsyncEngine = create_async_engine(
            url,
            pool_pre_ping=True,
            hide_parameters=True,
        )
        self._sessions = async_sessionmaker(
            self.engine,
            expire_on_commit=False,
        )

    def session(
        self,
    ) -> AsyncSession:
        return self._sessions()

    async def check(
        self,
    ) -> None:
        async with self.engine.connect() as connection:
            await connection.execute(
                text(
                    "SELECT id FROM billing_owners LIMIT 1",
                ),
            )

    async def close(
        self,
    ) -> None:
        await self.engine.dispose()

    async def lock_owner(
        self,
        session: AsyncSession,
        owner_id: str,
    ) -> BillingOwnerDB:
        owner = await session.scalar(
            select(
                BillingOwnerDB,
            )
            .where(
                BillingOwnerDB.id == owner_id,
            )
            .with_for_update(),
        )
        if owner is None:
            raise BillingAccessDeniedError()
        return owner
