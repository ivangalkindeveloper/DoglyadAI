from __future__ import annotations

import asyncio
import os
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import func, select

from app.core.configuration.configuration import Configuration
from app.database.billing_event_db import BillingEventDB
from app.database.billing_subscription_db import BillingSubscriptionDB
from app.error.billing_limit_error import BillingLimitError
from tests.support.billing.billing_test_context import BillingTestContext

pytestmark = pytest.mark.skipif(
    not os.environ.get(
        "DOGLYAD_TEST_POSTGRES_URL",
    ),
    reason="Requires an isolated PostgreSQL test database",
)


def test_parallel_quota_reservations_cannot_exceed_paid_limit(
    tmp_path: Path,
    configuration: Configuration,
) -> None:
    async def run() -> None:
        configuration.application["entitlements"]["base"]["requestCountPerDay"] = 2
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            async with ctx.database.session() as session, session.begin():
                session.add(
                    BillingSubscriptionDB(
                        id=str(
                            uuid4(),
                        ),
                        owner_id=owner,
                        source="yookassa",
                        external_id="parallel-quota",
                        plan_id="monthly",
                        entitlement="base",
                        paid_until=datetime.now(
                            UTC,
                        )
                        + timedelta(
                            days=1,
                        ),
                        updated_at=datetime.now(
                            UTC,
                        ),
                    ),
                )
            results = await asyncio.gather(
                *(
                    ctx.service.reserve(
                        owner,
                        str(
                            uuid4(),
                        ),
                    )
                    for _ in range(
                        16,
                    )
                ),
                return_exceptions=True,
            )
            assert (
                sum(
                    (result is None for result in results),
                )
                == 2
            )
            assert (
                sum(
                    (
                        isinstance(
                            result,
                            BillingLimitError,
                        )
                        for result in results
                    ),
                )
                == 14
            )
            assert (
                await ctx.service.status(
                    owner,
                )
            ).availableCountPerDay == 0

    asyncio.run(
        run(),
    )


def test_parallel_checkouts_and_callbacks_grant_one_period(
    tmp_path: Path,
    configuration: Configuration,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            first = await ctx.service.create_checkout(
                owner,
                "monthly",
            )
            second = await ctx.service.create_checkout(
                owner,
                "monthly",
            )
            browser_first, _ = await ctx.service.bind_checkout(
                first.code,
                None,
            )
            browser_second, _ = await ctx.service.bind_checkout(
                second.code,
                None,
            )
            urls = await asyncio.gather(
                ctx.service.start_checkout_payment(
                    browser_first,
                    is_auto_renewal_accepted=True,
                ),
                ctx.service.start_checkout_payment(
                    browser_second,
                    is_auto_renewal_accepted=True,
                ),
            )
            assert urls[0] == urls[1]
            assert (
                len(
                    ctx.payments,
                )
                == 1
            )
            assert (
                sum(
                    (request.method == "POST" for request in ctx.requests),
                )
                == 1
            )
            payment = next(
                iter(
                    ctx.payments.values(),
                ),
            )
            payment.update(
                status="succeeded",
                paid=True,
            )
            await asyncio.gather(
                *(
                    ctx.service.payment_notification(
                        payment["id"],
                    )
                    for _ in range(
                        16,
                    )
                ),
            )
            async with ctx.database.session() as session:
                assert (
                    await session.scalar(
                        select(
                            func.count(),
                        ).select_from(
                            BillingSubscriptionDB,
                        ),
                    )
                    == 1
                )
                assert (
                    await session.scalar(
                        select(
                            func.count(),
                        ).select_from(
                            BillingEventDB,
                        ),
                    )
                    == 1
                )
            status = await ctx.service.status(
                owner,
            )
            assert status.type == "pro" and status.expiresAt < datetime.now(
                UTC,
            ) + timedelta(
                days=32,
            )

    asyncio.run(
        run(),
    )


def test_parallel_sdk_requests_use_one_tokenized_payment(
    tmp_path: Path,
    configuration: Configuration,
) -> None:
    from app.core.localization.language_code import LanguageCode
    from app.model.billing.billing_tokenize_payment_request import BillingTokenizePaymentRequest

    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            prepared = await asyncio.gather(
                *(
                    ctx.sdk.prepare(
                        owner,
                        "monthly",
                        LanguageCode.RU,
                    )
                    for _ in range(
                        8,
                    )
                ),
            )
            assert (
                len(
                    {result.payment.id for result in prepared},
                )
                == 1
            )
            request = BillingTokenizePaymentRequest(
                paymentId=prepared[0].payment.id,
                paymentToken="parallel-sdk-token",
                termsVersion=prepared[0].termsVersion,
                isAutoRenewalAccepted=True,
            )
            responses = await asyncio.gather(
                *(
                    ctx.sdk.tokenize(
                        owner,
                        request,
                    )
                    for _ in range(
                        8,
                    )
                ),
            )
            assert all(
                (response.status == "pending" for response in responses),
            )
            assert (
                len(
                    ctx.payments,
                )
                == 1
            )
            assert (
                sum(
                    (item.method == "POST" for item in ctx.requests),
                )
                == 1
            )

    asyncio.run(
        run(),
    )
