from __future__ import annotations

import asyncio
import os
from dataclasses import replace
from datetime import timedelta
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs
from uuid import uuid4

import httpx
import pytest
from sqlalchemy import func, select

from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.database.billing_payment_db import BillingPaymentDB
from app.database.billing_refund_db import BillingRefundDB
from app.database.billing_subscription_db import BillingSubscriptionDB
from app.error.billing_conflict_error import BillingConflictError
from app.error.billing_payment_error import BillingPaymentError
from app.error.billing_payment_rejected_error import BillingPaymentRejectedError
from app.error.billing_purchase_error import BillingPurchaseError
from app.model.billing.billing_prepare_payment_response import BillingPreparePaymentResponse
from tests.support.billing.billing_test_context import BillingTestContext


async def _paid(
    ctx: BillingTestContext,
    owner: str,
) -> tuple[BillingPreparePaymentResponse, dict[str, Any]]:
    prepared = await ctx.checkout.prepare(
        owner,
        "monthly",
        LanguageCode.RU,
    )
    payment = ctx.payments[
        str(
            prepared.payment.id,
        )
    ]
    payment.update(
        status="succeeded",
        paid=True,
    )
    await ctx.checkout.check(
        owner,
        str(
            prepared.payment.id,
        ),
    )
    return prepared, payment


async def _expire(
    ctx: BillingTestContext,
    owner: str,
) -> str:
    async with ctx.database.session() as session, session.begin():
        subscription = await session.scalar(
            select(
                BillingSubscriptionDB,
            ).where(
                BillingSubscriptionDB.owner_id == owner,
            ),
        )
        assert subscription is not None
        subscription.paid_until = ctx.service._now() - timedelta(
            seconds=1,
        )
        subscription.next_charge_at = subscription.paid_until
        return subscription.id


def _refund(
    ctx: BillingTestContext,
    payment: dict[str, Any],
    amount_minor: int,
    status: str = "succeeded",
) -> dict[str, Any]:
    record = {
        "id": str(
            uuid4(),
        ),
        "payment_id": payment["id"],
        "status": status,
        "amount": {"value": f"{amount_minor / 100:.2f}", "currency": "RUB"},
        "created_at": ctx.service._now().isoformat(),
    }
    ctx.refunds[record["id"]] = record
    if status == "succeeded":
        payment["refunded_amount"] = {"value": f"{amount_minor / 100:.2f}", "currency": "RUB"}
    return record


@pytest.mark.parametrize(
    "is_reserved",
    [False, True],
)
def test_new_purchase_replaces_only_unsent_expired_renewals(
    tmp_path: Path,
    configuration: Configuration,
    is_reserved: bool,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            await _paid(
                ctx,
                owner,
            )
            old_subscription = await _expire(
                ctx,
                owner,
            )
            if is_reserved:
                await ctx.service.tick()
            await _paid(
                ctx,
                owner,
            )
            await ctx.service.tick()
            await ctx.service.tick()
            assert (
                len(
                    ctx.payments,
                )
                == 2
            )
            async with ctx.database.session() as session:
                old = await session.get(
                    BillingSubscriptionDB,
                    old_subscription,
                )
                assert old is not None and not old.is_auto_renewing and old.next_charge_at is None
                assert (
                    await session.scalar(
                        select(
                            func.count(),
                        )
                        .select_from(
                            BillingSubscriptionDB,
                        )
                        .where(
                            BillingSubscriptionDB.is_auto_renewing.is_(
                                True,
                            ),
                        ),
                    )
                    == 1
                )

    asyncio.run(
        run(),
    )


def test_lost_renewal_response_survives_cancellation_and_reuses_dispatch_snapshot(
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
            first, _ = await _paid(
                ctx,
                owner,
            )
            await _expire(
                ctx,
                owner,
            )
            await ctx.service.tick()
            async with ctx.database.session() as session:
                renewal = await session.scalar(
                    select(
                        BillingPaymentDB,
                    ).where(
                        BillingPaymentDB.id
                        != str(
                            first.payment.id,
                        ),
                    ),
                )
                assert renewal is not None
                renewal_id = renewal.id
            original = ctx.client._transport

            def lose_response(
                request: httpx.Request,
            ) -> httpx.Response:
                response = ctx._respond(
                    request,
                )
                if request.method == "POST":
                    ctx.payments[
                        parse_qs(
                            request.content.decode(),
                        )["Shp_order_id"][0]
                    ].update(
                        status="succeeded",
                        paid=True,
                    )
                    raise httpx.ReadTimeout(
                        "test lost response",
                        request=request,
                    )
                return response

            ctx.client._transport = httpx.MockTransport(
                lose_response,
            )
            with pytest.raises(
                BillingPaymentError,
            ):
                await ctx.service.submit_payment(
                    renewal_id,
                )
            ctx.client._transport = original
            async with ctx.database.session() as session:
                renewal = await session.get(
                    BillingPaymentDB,
                    renewal_id,
                )
                assert renewal is not None and renewal.submitted_at is not None
                assert (
                    renewal.renewal_payment_method_id
                    == ctx.payments[
                        str(
                            first.payment.id,
                        )
                    ]["id"]
                )
            with pytest.raises(
                BillingConflictError,
            ):
                await ctx.checkout.prepare(
                    owner,
                    "monthly",
                    LanguageCode.RU,
                )
            await ctx.service.cancel(
                owner,
            )
            async with ctx.database.session() as session, session.begin():
                subscription = await session.scalar(
                    select(
                        BillingSubscriptionDB,
                    ),
                )
                assert subscription is not None
                subscription.payment_method_id = None
            await ctx.service.tick()
            async with ctx.database.session() as session:
                renewal = await session.get(
                    BillingPaymentDB,
                    renewal_id,
                )
                assert renewal is not None and renewal.status == "succeeded" and renewal.provider_id
            status = await ctx.service.status(
                owner,
            )
            assert status is not None and not status.isAutoRenewing
            retried = [
                request
                for request in ctx.requests
                if request.url.path.endswith(
                    "/Recurring",
                )
            ]
            assert (
                len(
                    retried,
                )
                == 1
            )
            assert (
                parse_qs(
                    retried[0].content.decode(),
                )["PreviousInvoiceID"][0]
                == ctx.payments[
                    str(
                        first.payment.id,
                    )
                ]["id"]
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


def test_definitive_invoice_rejection_allows_a_new_order(
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
            original = ctx.client._transport
            ctx.client._transport = httpx.MockTransport(
                lambda request: httpx.Response(
                    200,
                    json={"isSuccess": False},
                ),
            )
            with pytest.raises(
                BillingPaymentRejectedError,
            ):
                await ctx.checkout.prepare(
                    owner,
                    "monthly",
                    LanguageCode.RU,
                )
            ctx.client._transport = original
            async with ctx.database.session() as session:
                order = await session.scalar(
                    select(
                        BillingPaymentDB,
                    ),
                )
                assert order is not None and order.status == "canceled" and order.provider_id is None
                rejected_id = order.id
            fresh, _ = await _paid(
                ctx,
                owner,
            )
            assert (
                str(
                    fresh.payment.id,
                )
                != rejected_id
            )
            assert (
                len(
                    ctx.payments,
                )
                == 1
            )
            assert (
                await ctx.service.status(
                    owner,
                )
                is not None
            )

    asyncio.run(
        run(),
    )


def test_completed_payment_reconciliation_advances_past_a_failing_provider_object(
    tmp_path: Path,
    configuration: Configuration,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owners = [
                str(
                    (await ctx.service.register()).ownerId,
                )
                for _ in range(
                    2,
                )
            ]
            paid = [
                await _paid(
                    ctx,
                    owner,
                )
                for owner in owners
            ]
            bad_index = min(
                range(
                    2,
                ),
                key=lambda index: str(
                    paid[index][0].payment.id,
                ),
            )
            good_index = 1 - bad_index
            bad_id = paid[bad_index][1]["id"]
            _refund(
                ctx,
                paid[good_index][1],
                10000,
            )
            ctx.service._configuration = replace(
                configuration,
                server=configuration.server.model_copy(
                    update={
                        "billing": configuration.server.billing.model_copy(
                            update={"batch_size": 1},
                        ),
                    },
                ),
            )

            def respond(
                request: httpx.Request,
            ) -> httpx.Response:
                if request.url.path == "/payments/" + bad_id:
                    return httpx.Response(
                        500,
                        json={
                            "type": "error",
                            "id": str(
                                uuid4(),
                            ),
                            "code": "internal_server_error",
                        },
                    )
                return ctx._respond(
                    request,
                )

            ctx.client._transport = httpx.MockTransport(
                respond,
            )
            await ctx.service.tick()
            await ctx.service.tick()
            assert (
                await ctx.service.status(
                    owners[good_index],
                )
                is None
            )
            async with ctx.database.session() as session:
                bad = await session.get(
                    BillingPaymentDB,
                    str(
                        paid[bad_index][0].payment.id,
                    ),
                )
                assert bad is not None and bad.reconciliation_attempted_at is not None

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "status",
    [429, 500],
)
def test_uncertain_provider_error_keeps_invoice_and_never_replays_submission(
    tmp_path: Path,
    configuration: Configuration,
    status: int,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            original = ctx.client._transport
            ctx.client._transport = httpx.MockTransport(
                lambda request: httpx.Response(
                    status,
                    json={"error": "unknown"},
                ),
            )
            with pytest.raises(
                BillingPaymentError,
            ):
                await ctx.checkout.prepare(
                    owner,
                    "monthly",
                    LanguageCode.RU,
                )
            ctx.client._transport = original
            async with ctx.database.session() as session:
                order = await session.scalar(
                    select(
                        BillingPaymentDB,
                    ),
                )
                assert order is not None and order.submitted_at is not None
                order_id, invoice_id = order.id, order.invoice_id
            with pytest.raises(
                BillingPaymentError,
            ):
                await ctx.checkout.prepare(
                    owner,
                    "monthly",
                    LanguageCode.RU,
                )
            async with ctx.database.session() as session, session.begin():
                order = await session.get(
                    BillingPaymentDB,
                    order_id,
                )
                assert order is not None and order.invoice_id == invoice_id
                order.submitted_at = ctx.service._now() - timedelta(
                    hours=24,
                )
            await ctx.service.tick()
            assert (
                await ctx.checkout.check(
                    owner,
                    order_id,
                )
            ).status == "needsReview"
            assert not ctx.payments

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "amount_minor",
    [4000, 10000],
)
def test_worker_reconciles_known_refund_request_ids(
    tmp_path: Path,
    configuration: Configuration,
    amount_minor: int,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            prepared, payment = await _paid(
                ctx,
                owner,
            )
            before = await ctx.service.status(
                owner,
            )
            refund = _refund(
                ctx,
                payment,
                amount_minor,
            )
            async with ctx.database.session() as session, session.begin():
                session.add(
                    BillingRefundDB(
                        id=refund["id"],
                        provider_request_id=refund["id"],
                        payment_id=str(
                            prepared.payment.id,
                        ),
                        amount_minor=amount_minor,
                        currency="RUB",
                        status="pending",
                        created_at=ctx.service._now(),
                        updated_at=ctx.service._now(),
                    ),
                )
            await ctx.service.tick()
            await ctx.service.tick()
            async with ctx.database.session() as session:
                order = await session.get(
                    BillingPaymentDB,
                    str(
                        prepared.payment.id,
                    ),
                )
                recorded = await session.get(
                    BillingRefundDB,
                    refund["id"],
                )
                assert order is not None and order.refunded_amount_minor == amount_minor
                assert recorded is not None and recorded.amount_minor == amount_minor
                assert recorded.payment_id == order.id and recorded.currency == "RUB" and recorded.status == "succeeded"
                assert (
                    await session.scalar(
                        select(
                            func.count(),
                        ).select_from(
                            BillingRefundDB,
                        ),
                    )
                    == 1
                )
            after = await ctx.service.status(
                owner,
            )
            if amount_minor == 10000:
                assert after is None
                async with ctx.database.session() as session:
                    subscription = await session.scalar(
                        select(
                            BillingSubscriptionDB,
                        ),
                    )
                    assert subscription is not None and not subscription.is_auto_renewing
            else:
                assert before is not None and after is not None and after.expiresAt == before.expiresAt

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "final_status",
    ["succeeded", "canceled"],
)
def test_refund_status_transitions_are_idempotent_and_do_not_extend_access(
    tmp_path: Path,
    configuration: Configuration,
    final_status: str,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            prepared, payment = await _paid(
                ctx,
                owner,
            )
            before = await ctx.service.status(
                owner,
            )
            refund = _refund(
                ctx,
                payment,
                4000,
                "pending",
            )
            async with ctx.database.session() as session, session.begin():
                session.add(
                    BillingRefundDB(
                        id=refund["id"],
                        provider_request_id=refund["id"],
                        payment_id=str(
                            prepared.payment.id,
                        ),
                        amount_minor=4000,
                        currency="RUB",
                        status="pending",
                        created_at=ctx.service._now(),
                        updated_at=ctx.service._now(),
                    ),
                )
            await ctx.service.payment_notification(
                payment["id"],
            )
            refund["status"] = final_status
            payment["refunded_amount"] = {
                "value": "40.00" if final_status == "succeeded" else "0.00",
                "currency": "RUB",
            }
            await ctx.service.payment_notification(
                payment["id"],
            )
            await ctx.service.payment_notification(
                payment["id"],
            )
            async with ctx.database.session() as session:
                order = await session.get(
                    BillingPaymentDB,
                    str(
                        prepared.payment.id,
                    ),
                )
                record = await session.get(
                    BillingRefundDB,
                    refund["id"],
                )
                assert record is not None and record.status == final_status
                assert order is not None and order.refunded_amount_minor == (4000 if final_status == "succeeded" else 0)
                assert (
                    await session.scalar(
                        select(
                            func.count(),
                        ).select_from(
                            BillingRefundDB,
                        ),
                    )
                    == 1
                )
            after = await ctx.service.status(
                owner,
            )
            assert before is not None and after is not None and before.expiresAt == after.expiresAt

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "field,value",
    [
        ("payment_id", "other-payment"),
        ("amount", {"value": "40.00", "currency": "USD"}),
        ("amount", {"value": "-1.00", "currency": "RUB"}),
    ],
)
def test_invalid_refund_cannot_modify_the_money_ledger(
    tmp_path: Path,
    configuration: Configuration,
    field: str,
    value: Any,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            prepared, payment = await _paid(
                ctx,
                owner,
            )
            refund = _refund(
                ctx,
                payment,
                4000,
            )
            forged = {**refund, field: value}
            with pytest.raises(
                BillingPurchaseError,
            ):
                await ctx.service.apply_payment(
                    payment,
                    refunds=[forged],
                )
            async with ctx.database.session() as session:
                order = await session.get(
                    BillingPaymentDB,
                    str(
                        prepared.payment.id,
                    ),
                )
                assert order is not None and order.refunded_amount_minor == 0
                assert (
                    await session.scalar(
                        select(
                            func.count(),
                        ).select_from(
                            BillingRefundDB,
                        ),
                    )
                    == 0
                )

    asyncio.run(
        run(),
    )


@pytest.mark.skipif(
    not os.environ.get(
        "DOGLYAD_TEST_POSTGRES_URL",
    ),
    reason="Requires isolated PostgreSQL row locks",
)
def test_inflight_renewal_blocks_concurrent_new_purchase(
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
            first, _ = await _paid(
                ctx,
                owner,
            )
            await _expire(
                ctx,
                owner,
            )
            await ctx.service.tick()
            async with ctx.database.session() as session:
                renewal_id = await session.scalar(
                    select(
                        BillingPaymentDB.id,
                    ).where(
                        BillingPaymentDB.id
                        != str(
                            first.payment.id,
                        ),
                    ),
                )
                assert renewal_id is not None
            entered, release = asyncio.Event(), asyncio.Event()

            async def delayed(
                request: httpx.Request,
            ) -> httpx.Response:
                if request.method == "POST":
                    entered.set()
                    await release.wait()
                return ctx._respond(
                    request,
                )

            ctx.client._transport = httpx.MockTransport(
                delayed,
            )
            renewal = asyncio.create_task(
                ctx.service.submit_payment(
                    renewal_id,
                ),
            )
            await asyncio.wait_for(
                entered.wait(),
                5,
            )
            purchase = asyncio.create_task(
                ctx.checkout.prepare(
                    owner,
                    "monthly",
                    LanguageCode.RU,
                ),
            )
            release.set()
            await renewal
            with pytest.raises(
                BillingConflictError,
            ):
                await purchase
            assert (
                len(
                    ctx.payments,
                )
                == 2
            )

    asyncio.run(
        run(),
    )
