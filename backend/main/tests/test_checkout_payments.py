from __future__ import annotations

import asyncio
import hashlib
from pathlib import Path
from types import SimpleNamespace

import httpx
import pytest
from sqlalchemy import select

from app.core.application.application_factory import ApplicationFactory
from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.core.localization.language_code import LanguageCode
from app.database.billing_payment_db import BillingPaymentDB
from app.database.billing_subscription_db import BillingSubscriptionDB
from app.error.billing_access_denied_error import BillingAccessDeniedError
from app.error.billing_conflict_error import BillingConflictError
from app.model.billing.billing_price import BillingPrice
from tests.support.billing.billing_test_context import BillingTestContext


@pytest.mark.parametrize(
    "is_auto_renewing",
    [True, False],
)
def test_direct_checkout_preserves_paywall_choice_and_signed_callback_contact(
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
            prepared = await ctx.checkout.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
                is_auto_renewing=is_auto_renewing,
            )
            assert prepared.payment.status == "pending"
            assert prepared.checkoutUrl == "https://auth.robokassa.ru/merchant/Invoice/test"
            payload = ctx.decode_payload(
                ctx.requests[0],
            )
            assert (
                payload["AdditionalParameters"].get(
                    "Recurring",
                )
                == "true"
            ) is is_auto_renewing
            assert "Email" not in payload["AdditionalParameters"]
            async with ctx.database.session() as session:
                order = await session.get(
                    BillingPaymentDB,
                    str(
                        prepared.payment.id,
                    ),
                )
                assert order is not None and order.consent_at and order.is_auto_renewing is is_auto_renewing
                assert order.receipt_email is None and order.terms_version == "test-v1"
                invoice_id = order.invoice_id
            app = ApplicationFactory.create_payment(
                Variables(
                    environment="development",
                ),
            )
            app.state.container = SimpleNamespace(
                subscriptions=ctx.service,
            )
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(
                    app,
                ),
                base_url="https://pay.example",
            ) as client:
                fields = {
                    "InvId": invoice_id,
                    "OutSum": "100.000000",
                    "Shp_order_id": str(
                        prepared.payment.id,
                    ),
                    "EMail": "buyer@example.com",
                    "SignatureValue": "forged",
                }
                assert (
                    await client.post(
                        "/webhooks/robokassa",
                        data=fields,
                    )
                ).status_code == 400
                assert (
                    await ctx.service.status(
                        owner,
                    )
                    is None
                )
                ctx.payments[
                    str(
                        prepared.payment.id,
                    )
                ].update(
                    status="succeeded",
                    paid=True,
                )
                await ctx.service.payment_notification(
                    invoice_id,
                )
                fields["SignatureValue"] = hashlib.sha256(
                    f"100.000000:{invoice_id}:test_password2:Shp_order_id={prepared.payment.id}".encode(),
                ).hexdigest()
                for _ in range(
                    2,
                ):
                    result = await client.post(
                        "/webhooks/robokassa",
                        data=fields,
                    )
                    assert result.status_code == 200 and result.text == "OK" + invoice_id
                first = await ctx.service.status(
                    owner,
                )
                assert first is not None and first.isAutoRenewing is is_auto_renewing
                assert (
                    await ctx.service.status(
                        owner,
                    )
                ).expiresAt == first.expiresAt
                async with ctx.database.session() as session:
                    subscription = await session.scalar(
                        select(
                            BillingSubscriptionDB,
                        ),
                    )
                    assert subscription is not None and subscription.receipt_email == "buyer@example.com"
                    assert (
                        bool(
                            subscription.payment_method_id,
                        )
                        is is_auto_renewing
                    )
                for path in ["/pay", "/pay/bind", "/pay/confirm", "/pay/complete"]:
                    assert (
                        await client.get(
                            path,
                        )
                    ).status_code == 404
                returned = await client.get(
                    "/payments/return",
                )
                assert returned.status_code == 303 and returned.headers["location"] == "doglyad://subscription/complete"
                assert returned.content == b""

    asyncio.run(
        run(),
    )


def test_direct_checkout_reuses_one_invoice_and_keeps_owner_isolation(
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
            other = str(
                (await ctx.service.register()).ownerId,
            )
            prepared = await ctx.checkout.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
            )
            repeated = await ctx.checkout.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
            )
            assert repeated.payment.id == prepared.payment.id
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
            with pytest.raises(
                BillingAccessDeniedError,
            ):
                await ctx.checkout.check(
                    other,
                    str(
                        prepared.payment.id,
                    ),
                )
            assert (
                await ctx.checkout.check(
                    owner,
                    str(
                        prepared.payment.id,
                    ),
                    is_abandoned=True,
                )
            ).status == "canceled"
            replacement = await ctx.checkout.prepare(
                owner,
                "monthly",
                LanguageCode.RU,
                is_auto_renewing=False,
            )
            assert replacement.payment.id != prepared.payment.id
            assert (
                len(
                    ctx.payments,
                )
                == 2
            )

    asyncio.run(
        run(),
    )


def test_changed_paywall_price_cannot_start_an_invoice(
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
            with pytest.raises(
                BillingConflictError,
            ):
                await ctx.checkout.prepare(
                    owner,
                    "monthly",
                    LanguageCode.RU,
                    expected_price=BillingPrice(
                        amountMinor=1,
                        currencyIso2Code="RUB",
                    ),
                )
            assert not ctx.requests and not ctx.payments

    asyncio.run(
        run(),
    )
