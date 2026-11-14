from __future__ import annotations

import asyncio
from pathlib import Path
from uuid import uuid4

import httpx
import pytest

from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.database.billing_refund_db import BillingRefundDB
from app.error.billing_payment_error import BillingPaymentError
from tests.support.billing.billing_test_context import BillingTestContext


@pytest.mark.parametrize(
    "is_response_lost",
    [False, True],
)
def test_refund_dispatch_is_never_replayed_and_worker_tracks_known_request(
    tmp_path: Path,
    configuration: Configuration,
    is_response_lost: bool,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
            environment="production",
            is_live=True,
            is_live_enabled=True,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
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
            await ctx.service.payment_notification(
                payment["id"],
            )
            before = await ctx.service.status(
                owner,
            )
            operation = str(
                uuid4(),
            )
            original = ctx.client._transport

            def lose(
                request: httpx.Request,
            ) -> httpx.Response:
                response = ctx._respond(
                    request,
                )
                if request.url.path.endswith(
                    "/Refund/Create",
                ):
                    raise httpx.ReadTimeout(
                        "lost response",
                        request=request,
                    )
                return response

            if is_response_lost:
                ctx.client._transport = httpx.MockTransport(
                    lose,
                )
                with pytest.raises(
                    BillingPaymentError,
                ):
                    await ctx.service.request_refund(
                        str(
                            prepared.payment.id,
                        ),
                        10000,
                        operation,
                    )
                ctx.client._transport = original
            else:
                await ctx.service.request_refund(
                    str(
                        prepared.payment.id,
                    ),
                    10000,
                    operation,
                )
            await ctx.service.request_refund(
                str(
                    prepared.payment.id,
                ),
                10000,
                operation,
            )
            assert (
                len(
                    ctx.refunds,
                )
                == 1
            )
            assert (
                sum(
                    (
                        request.url.path.endswith(
                            "/Refund/Create",
                        )
                        for request in ctx.requests
                    ),
                )
                == 1
            )
            async with ctx.database.session() as session:
                refund = await session.get(
                    BillingRefundDB,
                    operation,
                )
                assert refund
                if is_response_lost:
                    assert refund.status == "needsReview" and refund.provider_request_id is None
                    assert (
                        await ctx.service.status(
                            owner,
                        )
                    ).expiresAt == before.expiresAt
                    return
                assert refund.status == "pending" and refund.provider_request_id
                request_id = refund.provider_request_id
            ctx.refunds[request_id]["status"] = "succeeded"
            await ctx.service.tick()
            assert (
                await ctx.service.status(
                    owner,
                )
                is None
            )
            await ctx.service.tick()
            assert (
                sum(
                    (
                        request.url.path.endswith(
                            "/Refund/Create",
                        )
                        for request in ctx.requests
                    ),
                )
                == 1
            )

    asyncio.run(
        run(),
    )
