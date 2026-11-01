from __future__ import annotations

import asyncio
import json
import os
from dataclasses import replace
from datetime import timedelta
from pathlib import Path
from typing import Any
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
from app.error.billing_unavailable_error import BillingUnavailableError
from app.model.billing.billing_prepare_payment_response import BillingPreparePaymentResponse
from app.model.billing.billing_tokenize_payment_request import BillingTokenizePaymentRequest
from tests.support.billing.billing_test_context import BillingTestContext


async def _paid(
    ctx: BillingTestContext,
    owner: str,
) -> tuple[BillingPreparePaymentResponse, dict[str, Any]]:
    prepared = await ctx.sdk.prepare(
        owner,
        "monthly",
        LanguageCode.RU,
    )
    await ctx.sdk.tokenize(
        owner,
        BillingTokenizePaymentRequest(
            paymentId=prepared.payment.id,
            paymentToken="test-token-" + uuid4().hex,
            termsVersion=prepared.termsVersion,
            isAutoRenewalAccepted=True,
        ),
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
    await ctx.sdk.check(
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
@pytest.mark.parametrize(
    "channel",
    ["sdk", "redirect"],
)
def test_new_purchase_replaces_only_unsent_expired_renewals(
    tmp_path: Path,
    configuration: Configuration,
    is_reserved: bool,
    channel: str,
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
            if channel == "sdk":
                await _paid(
                    ctx,
                    owner,
                )
            else:
                checkout = await ctx.service.create_checkout(
                    owner,
                    "monthly",
                )
                browser, _ = await ctx.service.bind_checkout(
                    checkout.code,
                    None,
                )
                await ctx.service.start_checkout_payment(
                    browser,
                    is_auto_renewal_accepted=True,
                )
                payment = list(
                    ctx.payments.values(),
                )[-1]
                payment.update(
                    status="succeeded",
                    paid=True,
                )
                await ctx.service.payment_notification(
                    payment["id"],
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
                    ctx.payments[request.headers["Idempotence-Key"]].update(
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
                assert renewal.renewal_payment_method_id == "saved-method"
            with pytest.raises(
                BillingConflictError,
            ):
                await ctx.sdk.prepare(
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
                if request.method == "POST" and request.headers["Idempotence-Key"] == renewal_id
            ]
            assert (
                json.loads(
                    retried[-1].content,
                )["payment_method_id"]
                == "saved-method"
            )
            assert (
                len(
                    ctx.payments,
                )
                == 2
            )
            assert (
                sum(
                    (
                        request.method == "POST" and request.headers["Idempotence-Key"] == renewal_id
                        for request in ctx.requests
                    ),
                )
                == 2
            )

    asyncio.run(
        run(),
    )


def test_definitive_token_rejection_allows_a_new_order_and_token(
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
            prepared = await ctx.sdk.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
            )
            original = ctx.client._transport

            def reject(
                request: httpx.Request,
            ) -> httpx.Response:
                if request.method == "POST":
                    return httpx.Response(
                        400,
                        json={
                            "type": "error",
                            "id": str(
                                uuid4(),
                            ),
                            "code": "invalid_request",
                            "parameter": "payment_token",
                        },
                    )
                return ctx._respond(
                    request,
                )

            ctx.client._transport = httpx.MockTransport(
                reject,
            )
            with pytest.raises(
                BillingPaymentRejectedError,
            ):
                await ctx.sdk.tokenize(
                    owner,
                    BillingTokenizePaymentRequest(
                        paymentId=prepared.payment.id,
                        paymentToken="rejected-test-token",
                        termsVersion=prepared.termsVersion,
                        isAutoRenewalAccepted=True,
                    ),
                )
            ctx.client._transport = original
            async with ctx.database.session() as session:
                order = await session.get(
                    BillingPaymentDB,
                    str(
                        prepared.payment.id,
                    ),
                )
                assert order is not None and order.status == "canceled" and order.provider_id is None
            fresh, _ = await _paid(
                ctx,
                owner,
            )
            assert fresh.payment.id != prepared.payment.id
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


def test_failed_merchant_preflight_does_not_leave_an_unretryable_order(
    tmp_path: Path,
    configuration: Configuration,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
            is_live=True,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            prepared = await ctx.sdk.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
            )
            with pytest.raises(
                BillingUnavailableError,
            ):
                await ctx.sdk.tokenize(
                    owner,
                    BillingTokenizePaymentRequest(
                        paymentId=prepared.payment.id,
                        paymentToken="preflight-test-token",
                        termsVersion=prepared.termsVersion,
                        isAutoRenewalAccepted=True,
                    ),
                )
            assert not ctx.payments
            assert not any(
                (request.method == "POST" for request in ctx.requests),
            )
            ctx.is_live = False
            fresh, _ = await _paid(
                ctx,
                owner,
            )
            assert fresh.payment.id != prepared.payment.id

    asyncio.run(
        run(),
    )


def test_browser_checkout_can_retry_after_definitive_rejection(
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
            checkout = await ctx.service.create_checkout(
                owner,
                "monthly",
            )
            browser, _ = await ctx.service.bind_checkout(
                checkout.code,
                None,
            )
            original = ctx.client._transport

            def reject(
                request: httpx.Request,
            ) -> httpx.Response:
                if request.method == "POST":
                    return httpx.Response(
                        400,
                        json={
                            "type": "error",
                            "id": str(
                                uuid4(),
                            ),
                            "code": "invalid_request",
                        },
                    )
                return ctx._respond(
                    request,
                )

            ctx.client._transport = httpx.MockTransport(
                reject,
            )
            with pytest.raises(
                BillingPaymentRejectedError,
            ):
                await ctx.service.start_checkout_payment(
                    browser,
                    is_auto_renewal_accepted=True,
                )
            ctx.client._transport = original
            assert await ctx.service.start_checkout_payment(
                browser,
                is_auto_renewal_accepted=True,
            )
            assert (
                len(
                    ctx.payments,
                )
                == 1
            )
            async with ctx.database.session() as session:
                assert (
                    await session.scalar(
                        select(
                            func.count(),
                        )
                        .select_from(
                            BillingPaymentDB,
                        )
                        .where(
                            BillingPaymentDB.status == "canceled",
                        ),
                    )
                    == 1
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
                if request.url.path == "/v3/payments/" + bad_id:
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
def test_uncertain_provider_error_does_not_allow_a_new_token_or_operation(
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
            prepared = await ctx.sdk.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
            )
            original = ctx.client._transport

            def fail(
                request: httpx.Request,
            ) -> httpx.Response:
                if request.method == "POST":
                    return httpx.Response(
                        status,
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
                fail,
            )
            request = BillingTokenizePaymentRequest(
                paymentId=prepared.payment.id,
                paymentToken="uncertain-test-token",
                termsVersion=prepared.termsVersion,
                isAutoRenewalAccepted=True,
            )
            with pytest.raises(
                BillingPaymentError,
            ):
                await ctx.sdk.tokenize(
                    owner,
                    request,
                )
            ctx.client._transport = original
            reopened = await ctx.sdk.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
            )
            assert reopened.payment.id == prepared.payment.id
            with pytest.raises(
                BillingConflictError,
            ):
                await ctx.sdk.tokenize(
                    owner,
                    request.model_copy(
                        update={"paymentToken": "different-test-token"},
                    ),
                )
            async with ctx.database.session() as session, session.begin():
                order = await session.get(
                    BillingPaymentDB,
                    str(
                        prepared.payment.id,
                    ),
                )
                assert order is not None and order.submitted_at is not None
                order.submitted_at = ctx.service._now() - timedelta(
                    hours=24,
                )
            await ctx.service.tick()
            assert (
                await ctx.sdk.check(
                    owner,
                    str(
                        prepared.payment.id,
                    ),
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
def test_worker_recovers_missed_refunds_and_records_provider_refund_ids(
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
                ctx.sdk.prepare(
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
