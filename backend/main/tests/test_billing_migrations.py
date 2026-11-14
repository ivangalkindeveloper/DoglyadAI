from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, inspect

import app.database  # noqa: F401 - register the complete billing metadata
from app.database.billing_base import BillingBase


@pytest.fixture
def migration_database(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> tuple[Path, Config]:
    path = tmp_path / "billing.sqlite"
    monkeypatch.setenv(
        "BILLING_DATABASE_URL",
        f"sqlite+aiosqlite:///{path}",
    )
    config = Config(
        str(
            Path(
                __file__,
            )
            .resolve()
            .parents[1]
            / "alembic.ini",
        ),
    )
    return path, config


def test_migration_chain_has_one_base_and_matches_current_models(
    migration_database: tuple[Path, Config],
) -> None:
    path, config = migration_database
    scripts = ScriptDirectory.from_config(
        config,
    )
    assert scripts.get_heads() == ["0001_initial"]
    assert scripts.get_bases() == ["0001_initial"]
    assert (
        len(
            list(
                scripts.walk_revisions(),
            ),
        )
        == 1
    )
    command.upgrade(
        config,
        "head",
    )
    engine = create_engine(
        f"sqlite:///{path}",
    )
    try:
        with engine.connect() as connection:
            assert set(
                inspect(
                    connection,
                ).get_table_names(),
            ) == {*BillingBase.metadata.tables, "alembic_version"}
            context = MigrationContext.configure(
                connection,
                opts={"compare_type": True, "compare_server_default": True},
            )
            assert (
                compare_metadata(
                    context,
                    BillingBase.metadata,
                )
                == []
            )
        with sqlite3.connect(
            path,
        ) as connection:
            assert connection.execute(
                "SELECT version_num FROM alembic_version",
            ).fetchall() == [("0001_initial",)]
    finally:
        engine.dispose()


def test_initial_schema_enforces_provider_identity_and_keeps_data_on_repeated_upgrade(
    migration_database: tuple[Path, Config],
) -> None:
    path, config = migration_database
    command.upgrade(
        config,
        "head",
    )
    insert_subscription = (
        "INSERT INTO billing_subscriptions "
        "(id, owner_id, source, apple_environment, external_id, plan_id, entitlement, paid_until, "
        "is_revoked, is_auto_renewing, amount_minor, interval_months, currency, updated_at) "
        "VALUES (?, 'owner', ?, ?, 'same-external-id', 'monthly', 'pro', '2027-11-01 00:00:00', "
        "0, 1, 10000, 1, 'RUB', '2026-11-01 00:00:00')"
    )
    with sqlite3.connect(
        path,
    ) as connection:
        connection.execute(
            "PRAGMA foreign_keys=ON",
        )
        connection.execute(
            "INSERT INTO billing_owners (id, created_at) VALUES ('owner', '2026-11-01 00:00:00')",
        )
        for values in [
            ("production", "apple", "Production"),
            ("sandbox", "apple", "Sandbox"),
            ("robokassa", "robokassa", None),
        ]:
            connection.execute(
                insert_subscription,
                values,
            )
        for values in [
            ("duplicate-production", "apple", "Production"),
            ("duplicate-sandbox", "apple", "Sandbox"),
            ("duplicate-robokassa", "robokassa", None),
            ("missing-environment", "apple", None),
            ("invalid-environment", "apple", "Unknown"),
            ("unexpected-environment", "robokassa", "Sandbox"),
            ("unknown-provider", "unsupported", None),
        ]:
            with pytest.raises(
                sqlite3.IntegrityError,
            ):
                connection.execute(
                    insert_subscription,
                    values,
                )
        connection.execute(
            "INSERT INTO billing_payments "
            "(id, invoice_id, owner_id, plan_id, entitlement, amount_minor, interval_months, "
            "currency, status, created_at, is_receipt_pending, is_auto_renewing) "
            "VALUES ('payment', '123', 'owner', 'monthly', 'pro', 10000, 1, 'RUB', 'succeeded', "
            "'2026-11-01 00:00:00', 1, 1)",
        )
        assert connection.execute(
            "SELECT channel, interval_days, refunded_amount_minor FROM billing_payments",
        ).fetchone() == ("redirect", 0, 0)
        for index in range(
            2,
        ):
            connection.execute(
                "INSERT INTO billing_refunds (id, payment_id, amount_minor, currency, status, created_at, updated_at) "
                "VALUES (?, 'payment', 1000, 'RUB', 'succeeded', '2026-11-01 00:00:00', '2026-11-01 00:00:00')",
                (f"refund-{index}",),
            )
    command.upgrade(
        config,
        "head",
    )
    with sqlite3.connect(
        path,
    ) as connection:
        assert connection.execute(
            "SELECT count(*) FROM billing_subscriptions",
        ).fetchone() == (3,)
        assert connection.execute(
            "SELECT count(*) FROM billing_refunds",
        ).fetchone() == (2,)
        assert connection.execute(
            "SELECT interval_days FROM billing_subscriptions",
        ).fetchall() == [(0,), (0,), (0,)]


def test_initial_downgrade_can_recreate_an_empty_ledger_but_rejects_existing_data(
    migration_database: tuple[Path, Config],
) -> None:
    path, config = migration_database
    command.upgrade(
        config,
        "head",
    )
    with pytest.raises(
        RuntimeError,
        match="requires an online empty database",
    ):
        command.downgrade(
            config,
            "0001_initial:base",
            sql=True,
        )
    command.downgrade(
        config,
        "base",
    )
    with sqlite3.connect(
        path,
    ) as connection:
        assert connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'",
        ).fetchall() == [("alembic_version",)]
        assert (
            connection.execute(
                "SELECT version_num FROM alembic_version",
            ).fetchall()
            == []
        )
    command.upgrade(
        config,
        "head",
    )
    with sqlite3.connect(
        path,
    ) as connection:
        connection.execute(
            "INSERT INTO billing_owners (id, created_at) VALUES ('owner', '2026-11-01 00:00:00')",
        )
    with pytest.raises(
        RuntimeError,
        match="Cannot drop a populated billing ledger",
    ):
        command.downgrade(
            config,
            "base",
        )
    with sqlite3.connect(
        path,
    ) as connection:
        assert connection.execute(
            "SELECT id FROM billing_owners",
        ).fetchall() == [("owner",)]
        assert connection.execute(
            "SELECT version_num FROM alembic_version",
        ).fetchall() == [("0001_initial",)]
