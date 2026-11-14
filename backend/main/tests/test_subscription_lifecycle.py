from __future__ import annotations

import asyncio
import os
from datetime import timedelta
from pathlib import Path

import pytest
from sqlalchemy import select

from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.database.billing_owner_db import BillingOwnerDB
from app.database.billing_payment_db import BillingPaymentDB
from app.database.billing_subscription_db import BillingSubscriptionDB
from app.error.billing_conflict_error import BillingConflictError
from tests.support.billing.billing_test_context import BillingTestContext


async def _pay(
    ctx: BillingTestContext,
    owner: str,
    plan: str = "monthly",
    *,
    is_auto_renewing: bool = True,
) -> str:
    prepared = await ctx.checkout.prepare(
        owner,
        plan,
        LanguageCode.RU,
        is_auto_renewing=is_auto_renewing,
    )
    order_id = str(
        prepared.payment.id,
    )
    ctx.payments[order_id].update(
        status="succeeded",
        paid=True,
    )
    response = await ctx.checkout.check(
        owner,
        order_id,
    )
    assert response.status == "succeeded" and response.recoveryKey
    return order_id


@pytest.mark.parametrize(
    ("previous_plan", "new_plan"),
    [("base.monthly", "pro.monthly"), ("pro.monthly", "base.weekly")],
)
def test_paid_plan_change_starts_immediately_and_replaces_previous_access(
    tmp_path: Path,
    configuration: Configuration,
    previous_plan: str,
    new_plan: str,
) -> None:
    async def run() -> None:
        catalog = {
            "termsVersion": "test-v1",
            "tiers": [
                {
                    "id": tier,
                    "titleLocaleKey": f"paywall{tier.title()}Label",
                    "featureLocaleKeys": [f"paywall{tier.title()}ModelsDescription"],
                }
                for tier in ("base", "pro")
            ],
            "products": [
                {
                    "id": identifier,
                    "period": period,
                    "entitlement": tier,
                    "titleLocaleKey": f"subscription{tier.title()}{period.title()}Label",
                    "priceTemplateLocaleKey": f"subscription{period.title()}PriceDescription",
                    "price": {"amountMinor": amount, "currencyIso2Code": "RUB"},
                }
                for identifier, period, tier, amount in [
                    ("base.monthly", "monthly", "base", 30000),
                    ("pro.monthly", "monthly", "pro", 60000),
                    ("base.weekly", "weekly", "base", 10000),
                ]
            ],
        }
        async with BillingTestContext(
            tmp_path,
            configuration,
            catalog=catalog,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            first_payment = await _pay(
                ctx,
                owner,
                previous_plan,
            )
            before = await ctx.service.status(
                owner,
            )
            now = ctx.service._now() + timedelta(
                days=1,
            )
            ctx.service._now = lambda: now
            second_payment = await _pay(
                ctx,
                owner,
                new_plan,
            )
            after = await ctx.service.status(
                owner,
            )
            assert after is not None and before is not None
            assert (
                after.planId == new_plan
                and after.type
                == new_plan.split(
                    ".",
                )[0]
            )
            async with ctx.database.session() as session:
                first_order = await session.get(
                    BillingPaymentDB,
                    first_payment,
                )
                second_order = await session.get(
                    BillingPaymentDB,
                    second_payment,
                )
                previous = await session.get(
                    BillingSubscriptionDB,
                    first_order.subscription_id,
                )
                current = await session.get(
                    BillingSubscriptionDB,
                    second_order.subscription_id,
                )
                assert second_order.amount_minor == (60000 if new_plan == "pro.monthly" else 10000)
                assert (
                    ctx.service._utc(
                        current.starts_at,
                    )
                    == now
                )
                assert previous.is_revoked and not previous.is_auto_renewing and previous.next_charge_at is None
                assert current.is_auto_renewing and not current.is_revoked
                assert current.next_charge_at == current.paid_until
                assert after.expiresAt == ctx.service._utc(
                    current.paid_until,
                )
            # Repeated old notifications never restore the replaced plan.
            await ctx.checkout.check(
                owner,
                first_payment,
            )
            assert (
                await ctx.service.status(
                    owner,
                )
            ).planId == new_plan
            count = len(
                ctx.payments,
            )
            await ctx.service.set_auto_renewal(
                owner,
                False,
            )
            await ctx.service.set_auto_renewal(
                owner,
                False,
            )
            with pytest.raises(
                BillingConflictError,
            ):
                await ctx.service.set_auto_renewal(
                    owner,
                    True,
                )
            assert not (
                await ctx.service.status(
                    owner,
                )
            ).isAutoRenewing
            assert (
                len(
                    ctx.payments,
                )
                == count
            )
            ctx.service._now = lambda: after.expiresAt + timedelta(
                seconds=1,
            )
            assert (
                await ctx.service.status(
                    owner,
                )
                is None
            )

    asyncio.run(
        run(),
    )


def test_unpaid_or_canceled_replacement_keeps_the_current_subscription(
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
            await _pay(
                ctx,
                owner,
            )
            before = await ctx.service.status(
                owner,
            )
            prepared = await ctx.checkout.prepare(
                owner,
                "test.monthly",
                LanguageCode.RU,
            )
            assert (
                await ctx.service.status(
                    owner,
                )
                == before
            )
            canceled = await ctx.checkout.check(
                owner,
                str(
                    prepared.payment.id,
                ),
                is_abandoned=True,
            )
            assert canceled.status == "canceled"
            assert (
                await ctx.service.status(
                    owner,
                )
                == before
            )

    asyncio.run(
        run(),
    )


def test_restart_reuses_invoice_and_bank_processing_is_never_canceled(
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
            initial = await ctx.checkout.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
            )
            order_id = str(
                initial.payment.id,
            )
            ctx.payments[order_id]["is_processing"] = True
            repeated = await ctx.checkout.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
            )
            assert repeated.payment.id == initial.payment.id
            pending = await ctx.checkout.check(
                owner,
                order_id,
                is_abandoned=True,
            )
            assert pending.status == "pending"
            with pytest.raises(
                BillingConflictError,
            ):
                await ctx.checkout.prepare(
                    owner,
                    "test.monthly",
                    LanguageCode.RU,
                )
            async with ctx.database.session() as session, session.begin():
                order = await session.get(
                    BillingPaymentDB,
                    order_id,
                )
                order.created_at = ctx.service._now() - timedelta(
                    days=2,
                )
                order.submitted_at = order.created_at
            await ctx.service.tick()
            assert (
                await ctx.checkout.check(
                    owner,
                    order_id,
                )
            ).status == "needsReview"
            assert (
                len(
                    ctx.payments,
                )
                == 1
            )
            assert not any(
                (
                    request.url.path.endswith(
                        "/DeactivateInvoice",
                    )
                    for request in ctx.requests
                ),
            )
            ctx.payments[order_id].update(
                status="succeeded",
                paid=True,
            )
            response = await ctx.checkout.check(
                owner,
                order_id,
            )
            assert response.status == "succeeded" and response.recoveryKey
            assert (
                await ctx.service.status(
                    owner,
                )
            ).planId == "monthly"

    asyncio.run(
        run(),
    )


def test_changed_unpaid_choice_deactivates_old_invoice_before_replacement(
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
            first = await ctx.checkout.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
            )
            second = await ctx.checkout.prepare(
                owner,
                "test.monthly",
                LanguageCode.RU,
                is_auto_renewing=False,
            )
            assert first.payment.id != second.payment.id
            assert (
                await ctx.checkout.check(
                    owner,
                    str(
                        first.payment.id,
                    ),
                )
            ).status == "canceled"
            paths = [
                request.url.path.rsplit(
                    "/",
                    1,
                )[-1]
                for request in ctx.requests
            ]
            assert (
                paths.index(
                    "DeactivateInvoice",
                )
                < len(
                    paths,
                )
                - 1
            )
            assert (
                paths.count(
                    "CreateInvoice",
                )
                == 2
            )
            assert (
                await ctx.service.status(
                    owner,
                )
                is None
            )

    asyncio.run(
        run(),
    )


def test_late_success_on_prepare_returns_exact_paid_order_and_stable_encrypted_key(
    tmp_path: Path,
    configuration: Configuration,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            identity = await ctx.service.register()
            owner = str(
                identity.ownerId,
            )
            first = await ctx.checkout.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
            )
            order_id = str(
                first.payment.id,
            )
            ctx.payments[order_id].update(
                status="succeeded",
                paid=True,
            )
            resumed = await ctx.checkout.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
            )
            assert resumed.payment.id == first.payment.id and resumed.payment.status == "succeeded"
            key = resumed.payment.recoveryKey
            assert (
                key
                and key
                == (
                    await ctx.service.status(
                        owner,
                    )
                ).recoveryKey
            )
            assert (
                await ctx.service.recovery_key(
                    owner,
                )
                == key
            )
            assert (
                await ctx.service.recover(
                    key,
                )
            ).ownerId == identity.ownerId
            async with ctx.database.session() as session:
                record = await session.get(
                    BillingOwnerDB,
                    owner,
                )
                assert record.recovery_ciphertext and key.encode() not in record.recovery_ciphertext
                assert record.recovery_hash != key
            assert (
                len(
                    ctx.payments,
                )
                == 1
            )

    asyncio.run(
        run(),
    )


def test_one_time_subscription_requires_new_paid_authorization_to_enable_renewal(
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
            await _pay(
                ctx,
                owner,
                is_auto_renewing=False,
            )
            before = await ctx.service.status(
                owner,
            )
            assert not before.isAutoRenewing
            with pytest.raises(
                BillingConflictError,
            ):
                await ctx.service.set_auto_renewal(
                    owner,
                    True,
                )
            after = await ctx.service.status(
                owner,
            )
            assert (
                before.expiresAt == after.expiresAt
                and len(
                    ctx.payments,
                )
                == 1
            )
            await _pay(
                ctx,
                owner,
                is_auto_renewing=True,
            )
            status = await ctx.service.status(
                owner,
            )
            assert status.isAutoRenewing
            assert status.planId == "monthly"

    asyncio.run(
        run(),
    )


def test_disabling_renewal_also_applies_to_a_late_paid_plan_change(
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
            await _pay(
                ctx,
                owner,
            )
            prepared = await ctx.checkout.prepare(
                owner,
                "test.monthly",
                LanguageCode.RU,
            )
            order_id = str(
                prepared.payment.id,
            )
            await ctx.service.set_auto_renewal(
                owner,
                False,
            )
            ctx.payments[order_id].update(
                status="succeeded",
                paid=True,
            )
            assert (
                await ctx.checkout.check(
                    owner,
                    order_id,
                )
            ).status == "succeeded"
            status = await ctx.service.status(
                owner,
            )
            assert status.planId == "test.monthly" and not status.isAutoRenewing
            async with ctx.database.session() as session:
                subscriptions = list(
                    await session.scalars(
                        select(
                            BillingSubscriptionDB,
                        ),
                    ),
                )
                assert all(
                    (
                        not subscription.is_auto_renewing and subscription.next_charge_at is None
                        for subscription in subscriptions
                    ),
                )
            assert (
                len(
                    ctx.payments,
                )
                == 2
            )

    asyncio.run(
        run(),
    )


@pytest.mark.skipif(
    not os.environ.get(
        "DOGLYAD_TEST_POSTGRES_URL",
    ),
    reason="Requires PostgreSQL row locks",
)
def test_concurrent_key_requests_return_the_same_recovery_key(
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
            keys = await asyncio.gather(
                ctx.service.recovery_key(
                    owner,
                ),
                ctx.service.recovery_key(
                    owner,
                ),
            )
            assert (
                len(
                    set(
                        keys,
                    ),
                )
                == 1
            )
            restored = await ctx.service.recover(
                keys[0],
            )
            assert (
                str(
                    restored.ownerId,
                )
                == owner
                and restored.recoveryKey == keys[0]
            )

    asyncio.run(
        run(),
    )
