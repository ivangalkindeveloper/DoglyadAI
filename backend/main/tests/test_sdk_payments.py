from __future__ import annotations

import asyncio
import hashlib
import json
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

import pytest

from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.database.billing_payment_db import BillingPaymentDB
from app.error.billing_access_denied_error import BillingAccessDeniedError
from app.error.billing_conflict_error import BillingConflictError
from app.error.billing_purchase_error import BillingPurchaseError
from app.model.billing.billing_tokenize_payment_request import BillingTokenizePaymentRequest
from tests.support.billing.billing_test_context import BillingTestContext


def test_sdk_token_order_retries_and_canonical_success(
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
            assert prepared.payment.status == "awaitingToken" and not ctx.payments
            assert prepared.payment.planId == "monthly"
            assert prepared.price.amountMinor == 10000 and prepared.shopId == "123"
            assert (
                await ctx.sdk.prepare(
                    owner,
                    "monthly",
                    LanguageCode.RU,
                )
            ).payment.id == prepared.payment.id
            request = BillingTokenizePaymentRequest(
                paymentId=prepared.payment.id,
                paymentToken="sdk-test-token",
                termsVersion=prepared.termsVersion,
                isAutoRenewalAccepted=True,
            )
            response = await ctx.sdk.tokenize(
                owner,
                request,
            )
            assert response.status == "pending" and response.paymentMethodType == "bank_card"
            assert response.id == prepared.payment.id and response.planId == "monthly"
            assert (
                await ctx.service.status(
                    owner,
                )
                is None
            )
            await ctx.sdk.tokenize(
                owner,
                request,
            )
            assert (
                len(
                    ctx.payments,
                )
                == 1
            )
            posted = [item for item in ctx.requests if item.method == "POST"]
            assert (
                len(
                    posted,
                )
                == 1
            )
            payload = json.loads(
                posted[0].content,
            )
            assert payload["payment_token"] == request.paymentToken and payload["save_payment_method"] is True
            assert "confirmation" not in payload  # Confirmation scenario is embedded in the SDK token.
            assert payload["amount"] == {"value": "100.00", "currency": "RUB"}
            async with ctx.database.session() as session:
                order = await session.get(
                    BillingPaymentDB,
                    str(
                        prepared.payment.id,
                    ),
                )
                assert (
                    order.payment_token_hash
                    == hashlib.sha256(
                        request.paymentToken.encode(),
                    ).hexdigest()
                )
                assert order.consent_at and order.terms_version == prepared.termsVersion
            payment = next(
                iter(
                    ctx.payments.values(),
                ),
            )
            payment.update(
                status="succeeded",
                paid=True,
            )
            assert (
                await ctx.sdk.check(
                    owner,
                    str(
                        prepared.payment.id,
                    ),
                )
            ).status == "succeeded"
            assert (
                await ctx.service.status(
                    owner,
                )
            ).type == "pro"

    asyncio.run(
        run(),
    )


def test_sdk_abandon_before_token_does_not_charge(
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
                LanguageCode.EN,
            )
            canceled = await ctx.sdk.check(
                owner,
                str(
                    prepared.payment.id,
                ),
                is_abandoned=True,
            )
            assert canceled.status == "canceled"
            result = await ctx.sdk.tokenize(
                owner,
                BillingTokenizePaymentRequest(
                    paymentId=prepared.payment.id,
                    paymentToken="late-token",
                    termsVersion=prepared.termsVersion,
                    isAutoRenewalAccepted=True,
                ),
            )
            assert result.status == "canceled" and not ctx.payments
            assert (
                await ctx.sdk.prepare(
                    owner,
                    "monthly",
                    LanguageCode.EN,
                )
            ).payment.id != prepared.payment.id

    asyncio.run(
        run(),
    )


def test_sdk_rejects_other_owner_and_changed_token(
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
            prepared = await ctx.sdk.prepare(
                owner,
                "monthly",
                LanguageCode.EN,
            )
            request = BillingTokenizePaymentRequest(
                paymentId=prepared.payment.id,
                paymentToken="first-token",
                termsVersion=prepared.termsVersion,
                isAutoRenewalAccepted=True,
            )
            with pytest.raises(
                BillingAccessDeniedError,
            ):
                await ctx.sdk.tokenize(
                    other,
                    request,
                )
            with pytest.raises(
                BillingAccessDeniedError,
            ):
                await ctx.sdk.check(
                    other,
                    str(
                        prepared.payment.id,
                    ),
                )
            with pytest.raises(
                BillingPurchaseError,
            ):
                await ctx.sdk.tokenize(
                    owner,
                    request.model_copy(
                        update={"isAutoRenewalAccepted": False},
                    ),
                )
            with pytest.raises(
                BillingConflictError,
            ):
                await ctx.sdk.tokenize(
                    owner,
                    request.model_copy(
                        update={"termsVersion": "wrong"},
                    ),
                )
            await ctx.sdk.tokenize(
                owner,
                request,
            )
            with pytest.raises(
                BillingConflictError,
            ):
                await ctx.sdk.tokenize(
                    owner,
                    request.model_copy(
                        update={"paymentToken": "different-token"},
                    ),
                )
            assert (
                len(
                    ctx.payments,
                )
                == 1
            )

    asyncio.run(
        run(),
    )


def test_worker_never_invents_missing_sdk_token(
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
                LanguageCode.EN,
            )
            async with ctx.database.session() as session, session.begin():
                order = await session.get(
                    BillingPaymentDB,
                    str(
                        prepared.payment.id,
                    ),
                )
                order.status = "created"
                order.payment_token_hash = "a" * 64
                order.consent_at = datetime.now(
                    UTC,
                )
            await ctx.service.tick()
            assert (
                not ctx.payments
                and await ctx.service.status(
                    owner,
                )
                is None
            )
            with pytest.raises(
                BillingAccessDeniedError,
            ):
                await ctx.sdk.check(
                    owner,
                    str(
                        uuid4(),
                    ),
                )

    asyncio.run(
        run(),
    )


def test_sdk_api_uses_authenticated_owner_and_rejects_client_price(
    tmp_path: Path,
    configuration: Configuration,
) -> None:
    from types import SimpleNamespace

    import httpx

    from app.core.app_check.app_check import AppCheck
    from app.core.application.application_factory import ApplicationFactory
    from app.core.configuration.variables import Variables

    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            identity = await ctx.service.register()
            app = ApplicationFactory.create_main(
                Variables(
                    environment="development",
                ),
            )
            app.state.container = SimpleNamespace(
                subscriptions=ctx.service,
                sdk_payments=ctx.sdk,
                configuration=configuration,
            )
            app.dependency_overrides[AppCheck.verify] = lambda: None
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(
                    app,
                ),
                base_url="https://api.example",
            ) as client:
                headers = {"Authorization": "Bearer " + identity.accessToken}
                assert (
                    await client.post(
                        "/v1/subscriptions/prepare_payment",
                        json={"planId": "monthly"},
                    )
                ).status_code == 401
                rejected = await client.post(
                    "/v1/subscriptions/prepare_payment",
                    headers=headers,
                    json={"planId": "monthly", "amountMinor": 1},
                )
                assert rejected.status_code == 422
                prepared = await client.post(
                    "/v1/subscriptions/prepare_payment",
                    headers=headers,
                    json={"planId": "monthly"},
                )
                assert prepared.status_code == 200
                assert prepared.headers["cache-control"] == "no-store"
                body = prepared.json()
                response = await client.post(
                    "/v1/subscriptions/tokenize_payment",
                    headers=headers,
                    json={
                        "paymentId": body["payment"]["id"],
                        "paymentToken": "api-test-token",
                        "termsVersion": body["termsVersion"],
                        "isAutoRenewalAccepted": True,
                    },
                )
                assert response.status_code == 200 and response.json()["status"] == "pending"
                payment = next(
                    iter(
                        ctx.payments.values(),
                    ),
                )
                payment.update(
                    status="succeeded",
                    paid=True,
                )
                checked = await client.post(
                    "/v1/subscriptions/check_payment",
                    headers=headers,
                    json={"paymentId": body["payment"]["id"]},
                )
                assert checked.json()["status"] == "succeeded"

    asyncio.run(
        run(),
    )
