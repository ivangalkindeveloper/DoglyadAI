from __future__ import annotations

import asyncio

from alembic import context
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

import app.database  # noqa: F401 - register application metadata
from app.core.configuration.variables import Variables
from app.database.application_base import ApplicationBase


def _configure(
    connection: object,
) -> None:
    context.configure(
        connection=connection,
        target_metadata=ApplicationBase.metadata,
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


async def _run() -> None:
    url = Variables().database_url
    if not url:
        raise RuntimeError(
            "DATABASE_URL is required for migrations",
        )
    if context.is_offline_mode():
        context.configure(
            url=url,
            target_metadata=ApplicationBase.metadata,
            literal_binds=True,
        )
        with context.begin_transaction():
            context.run_migrations()
        return
    engine = create_async_engine(
        url,
        poolclass=NullPool,
    )
    try:
        async with engine.connect() as connection:
            await connection.run_sync(
                _configure,
            )
    finally:
        await engine.dispose()


asyncio.run(
    _run(),
)
