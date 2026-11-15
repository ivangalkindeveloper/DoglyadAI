from __future__ import annotations

import asyncio
from dataclasses import replace
from datetime import timedelta, timezone
from pathlib import Path

import pytest
from pydantic import ValidationError
from sqlalchemy import select

from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.database.billing_payment_db import BillingPaymentDB
from app.database.billing_subscription_db import BillingSubscriptionDB
from app.error.billing_legal_update_required_error import BillingLegalUpdateRequiredError
from app.model.billing.billing_prepare_payment_request import BillingPreparePaymentRequest
from app.service.billing.checkout_payment_service import CheckoutPaymentService
from app.service.billing.subscription_service import SubscriptionService
from tests.support.billing.billing_test_context import BillingTestContext


def _update_documents(
    ctx: BillingTestContext,
    configuration: Configuration,
) -> None:
    updated = replace(
        configuration,
        application={
            **configuration.application,
            "legalDate": (
                configuration.legal_date
                + timedelta(
                    days=1,
                )
            ).isoformat(),
        },
    )
    ctx.service = SubscriptionService(
        ctx.database,
        updated,
        ctx.variables,
        ctx.service._robokassa,
        ctx.apple,
    )
    ctx.checkout = CheckoutPaymentService(
        ctx.service,
        updated,
    )


async def _purchase(
    ctx: BillingTestContext,
) -> tuple[str, str]:
    owner = str(
        (await ctx.service.register()).ownerId,
    )
    prepared = await ctx.checkout.prepare(
        owner,
        "monthly",
        LanguageCode.RU,
        legal_date=ctx.service.legal_date,
    )
    order_id = str(
        prepared.payment.id,
    )
    ctx.payments[order_id].update(
        status="succeeded",
        paid=True,
    )
    await ctx.checkout.check(
        owner,
        order_id,
    )
    return owner, order_id


@pytest.mark.parametrize(
    "is_auto_renewing",
    [False, True],
)
def test_stale_acceptance_cannot_create_a_payment(
    tmp_path: Path,
    configuration: Configuration,
    is_auto_renewing: bool,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            with pytest.raises(
                BillingLegalUpdateRequiredError,
            ):
                await ctx.checkout.prepare(
                    owner,
                    "monthly",
                    LanguageCode.RU,
                    legal_date=configuration.legal_date
                    - timedelta(
                        days=1,
                    ),
                    is_auto_renewing=is_auto_renewing,
                )
            async with ctx.database.session() as session:
                assert (
                    await session.scalar(
                        select(
                            BillingPaymentDB.id,
                        ),
                    )
                    is None
                )
            assert not ctx.requests

    asyncio.run(
        run(),
    )


def test_updated_documents_disable_renewal_and_require_a_new_purchase(
    tmp_path: Path,
    configuration: Configuration,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner, order_id = await _purchase(
                ctx,
            )
            async with ctx.database.session() as session:
                subscription = await session.scalar(
                    select(
                        BillingSubscriptionDB,
                    ),
                )
                assert subscription is not None
                original_id, paid_until = subscription.id, subscription.paid_until
            _update_documents(
                ctx,
                configuration,
            )
            await ctx.service.tick()
            async with ctx.database.session() as session:
                original = await session.get(
                    BillingSubscriptionDB,
                    original_id,
                )
                assert original is not None and not original.is_auto_renewing and original.next_charge_at is None
                assert original.paid_until == paid_until and not original.is_revoked
            assert set(
                ctx.payments,
            ) == {order_id}
            with pytest.raises(
                BillingLegalUpdateRequiredError,
            ):
                await ctx.checkout.prepare(
                    owner,
                    "monthly",
                    LanguageCode.RU,
                    legal_date=configuration.legal_date,
                )
            prepared = await ctx.checkout.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
                legal_date=ctx.service.legal_date,
            )
            replacement = str(
                prepared.payment.id,
            )
            ctx.payments[replacement].update(
                status="succeeded",
                paid=True,
            )
            await ctx.checkout.check(
                owner,
                replacement,
            )
            async with ctx.database.session() as session:
                current = await session.scalar(
                    select(
                        BillingSubscriptionDB,
                    ).where(
                        BillingSubscriptionDB.is_revoked.is_(
                            False,
                        ),
                    ),
                )
                assert current is not None and current.id != original_id and current.is_auto_renewing
                assert (
                    ctx.service._utc(
                        current.legal_date,
                    )
                    == ctx.service.legal_date
                )

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "is_dispatch_marked",
    [False, True],
)
def test_prepared_renewal_is_blocked_before_provider_io(
    tmp_path: Path,
    configuration: Configuration,
    is_dispatch_marked: bool,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            _, initial = await _purchase(
                ctx,
            )
            async with ctx.database.session() as session, session.begin():
                subscription = await session.scalar(
                    select(
                        BillingSubscriptionDB,
                    ),
                )
                assert subscription is not None
                subscription.paid_until = ctx.service._now() - timedelta(
                    seconds=1,
                )
                subscription.next_charge_at = subscription.paid_until
            await ctx.service.tick()
            async with ctx.database.session() as session, session.begin():
                renewal = await session.scalar(
                    select(
                        BillingPaymentDB,
                    ).where(
                        BillingPaymentDB.period_key.is_not(
                            None,
                        ),
                    ),
                )
                assert renewal is not None
                renewal_id = renewal.id
                if is_dispatch_marked:
                    renewal.submitted_at = ctx.service._now()
            _update_documents(
                ctx,
                configuration,
            )
            if is_dispatch_marked:
                await ctx.service._dispatch_payment(
                    renewal_id,
                    is_initial_attempt=True,
                )
            else:
                await ctx.service.tick()
            async with ctx.database.session() as session:
                renewal = await session.get(
                    BillingPaymentDB,
                    renewal_id,
                )
                assert renewal is not None and renewal.status == "canceled"
                subscription = await session.scalar(
                    select(
                        BillingSubscriptionDB,
                    ),
                )
                assert (
                    subscription is not None
                    and not subscription.is_auto_renewing
                    and subscription.next_charge_at is None
                )
            assert set(
                ctx.payments,
            ) == {initial}

    asyncio.run(
        run(),
    )


def test_late_payment_confirmation_keeps_paid_access_without_renewal(
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
            prepared = await ctx.checkout.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
                legal_date=ctx.service.legal_date,
            )
            order_id = str(
                prepared.payment.id,
            )
            _update_documents(
                ctx,
                configuration,
            )
            ctx.payments[order_id].update(
                status="succeeded",
                paid=True,
            )
            response = await ctx.checkout.check(
                owner,
                order_id,
            )
            assert response.status == "succeeded"
            async with ctx.database.session() as session:
                subscription = await session.scalar(
                    select(
                        BillingSubscriptionDB,
                    ),
                )
                assert (
                    subscription is not None
                    and not subscription.is_auto_renewing
                    and subscription.next_charge_at is None
                )
                assert (
                    ctx.service._utc(
                        subscription.paid_until,
                    )
                    > ctx.service._now()
                )
            assert set(
                ctx.payments,
            ) == {order_id}

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "value",
    [None, "2026-11-15T00:00:00"],
)
def test_purchase_requires_an_explicit_timezone_aware_legal_date(
    value: str | None,
) -> None:
    data = {"planId": "monthly", "price": {"amountMinor": 10000, "currencyIso2Code": "RUB"}, "isAutoRenewing": True}
    if value is not None:
        data["legalDate"] = value
    with pytest.raises(
        ValidationError,
    ):
        BillingPreparePaymentRequest.model_validate(
            data,
        )


def test_equal_legal_instants_in_different_timezones_are_accepted(
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
            date = ctx.service.legal_date.astimezone(
                timezone(
                    timedelta(
                        hours=3,
                    ),
                ),
            )
            prepared = await ctx.checkout.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
                legal_date=date,
            )
            assert prepared.payment.status == "pending"
            assert (
                len(
                    ctx.payments,
                )
                == 1
            )

    asyncio.run(
        run(),
    )
