from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace

import pytest
from appstoreserverlibrary.models.Environment import Environment
from sqlalchemy import select, update

from app.core.configuration.configuration import Configuration
from app.database.billing_subscription_db import BillingSubscriptionDB
from app.error.billing_purchase_error import BillingPurchaseError
from tests.support.billing.billing_test_context import BillingTestContext


def test_apple_environments_keep_separate_transactions_and_reconciliation(
    tmp_path: Path,
    configuration: Configuration,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owners = {
                environment: str(
                    (await ctx.service.register()).ownerId,
                )
                for environment in (Environment.PRODUCTION, Environment.SANDBOX)
            }
            transactions = {
                environment: SimpleNamespace(
                    appAccountToken=owner,
                    originalTransactionId="shared-original-id",
                    productId="test.monthly",
                    expiresDate=int(
                        (
                            datetime.now(
                                UTC,
                            )
                            + timedelta(
                                days=30,
                            )
                        ).timestamp()
                        * 1000,
                    ),
                    revocationDate=None,
                )
                for environment, owner in owners.items()
            }
            renewal = SimpleNamespace(
                gracePeriodExpiresDate=None,
                autoRenewStatus=1,
            )
            ctx.apple.current.side_effect = lambda original_id, environment: (transactions[environment], renewal)
            for environment, owner in owners.items():
                ctx.apple.transaction.return_value = (transactions[environment], environment)
                await ctx.service.sync_apple(
                    owner,
                    "signed-proof",
                )
                await ctx.service.sync_apple(
                    owner,
                    "signed-proof",
                )
                status = await ctx.service.status(
                    owner,
                )
                assert status is not None and status.source == "apple"
            async with ctx.database.session() as session, session.begin():
                subscriptions = list(
                    await session.scalars(
                        select(
                            BillingSubscriptionDB,
                        ),
                    ),
                )
                assert (
                    len(
                        subscriptions,
                    )
                    == 2
                )
                assert {row.apple_environment: row.owner_id for row in subscriptions} == {
                    environment.value: owner for environment, owner in owners.items()
                }
                await session.execute(
                    update(
                        BillingSubscriptionDB,
                    ).values(
                        updated_at=datetime.now(
                            UTC,
                        )
                        - timedelta(
                            days=1,
                        ),
                    ),
                )
            ctx.apple.current.reset_mock()
            await ctx.service.reconcile_apple()
            assert {call.args for call in ctx.apple.current.call_args_list} == {
                ("shared-original-id", Environment.PRODUCTION),
                ("shared-original-id", Environment.SANDBOX),
            }
            ctx.variables.is_apple_sandbox_allowed = False
            ctx.apple.transaction.return_value = (transactions[Environment.SANDBOX], Environment.SANDBOX)
            with pytest.raises(
                BillingPurchaseError,
            ):
                await ctx.service.sync_apple(
                    owners[Environment.SANDBOX],
                    "signed-proof",
                )

    asyncio.run(
        run(),
    )
