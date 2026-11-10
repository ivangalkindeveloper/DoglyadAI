from __future__ import annotations

import asyncio
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace
from typing import Literal
from uuid import uuid4

import httpx
import pytest
from appstoreserverlibrary.models.Environment import Environment
from fastapi import FastAPI
from sqlalchemy import select

from app.core.application.application_factory import ApplicationFactory
from app.core.application.service_dependencies import ServiceDependencies
from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.database.billing_credential_db import BillingCredentialDB
from app.database.billing_subscription_db import BillingSubscriptionDB
from app.database.billing_usage_db import BillingUsageDB
from app.error.billing_access_denied_error import BillingAccessDeniedError
from app.error.billing_conflict_error import BillingConflictError
from app.error.billing_limit_error import BillingLimitError
from app.error.billing_purchase_error import BillingPurchaseError
from app.error.billing_unavailable_error import BillingUnavailableError
from tests.support.billing.billing_test_context import BillingTestContext


def test_identity_recovery_and_rotation(
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
            assert (
                await ctx.service.authenticate(
                    identity.accessToken,
                )
                == owner
            )
            key = await ctx.service.recovery_key(
                owner,
            )
            restored = await ctx.service.recover(
                key.lower(),
            )
            assert restored.ownerId == identity.ownerId
            assert restored.accessToken != identity.accessToken
            assert (
                await ctx.service.authenticate(
                    restored.accessToken,
                )
                == owner
            )
            await ctx.service.recovery_key(
                owner,
            )
            with pytest.raises(
                BillingAccessDeniedError,
            ):
                await ctx.service.recover(
                    key,
                )
            async with ctx.database.session() as session:
                credentials = list(
                    await session.scalars(
                        select(
                            BillingCredentialDB,
                        ),
                    ),
                )
                assert (
                    len(
                        credentials,
                    )
                    == 2
                )
                assert all(
                    (row.token_hash not in (identity.accessToken, restored.accessToken) for row in credentials),
                )

    asyncio.run(
        run(),
    )


def test_quota_refunds_failures_and_blocks_replays(
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
                BillingLimitError,
            ):
                await ctx.service.reserve(
                    owner,
                    str(
                        uuid4(),
                    ),
                )
            async with ctx.database.session() as session, session.begin():
                session.add(
                    BillingSubscriptionDB(
                        id=str(
                            uuid4(),
                        ),
                        owner_id=owner,
                        source="yookassa",
                        external_id="quota-fixture",
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
            initial = (
                await ctx.service.status(
                    owner,
                )
            ).availableCountPerDay
            operation = str(
                uuid4(),
            )
            await ctx.service.reserve(
                owner,
                operation,
            )
            await ctx.service.finish_usage(
                owner,
                operation,
                is_success=False,
            )
            assert (
                await ctx.service.status(
                    owner,
                )
            ).availableCountPerDay == initial
            with pytest.raises(
                BillingConflictError,
            ):
                await ctx.service.reserve(
                    owner,
                    operation,
                )
            for _ in range(
                initial,
            ):
                operation = str(
                    uuid4(),
                )
                await ctx.service.reserve(
                    owner,
                    operation,
                )
                await ctx.service.finish_usage(
                    owner,
                    operation,
                    is_success=True,
                )
            assert (
                await ctx.service.status(
                    owner,
                )
            ).availableCountPerDay == 0
            with pytest.raises(
                BillingLimitError,
            ):
                await ctx.service.reserve(
                    owner,
                    str(
                        uuid4(),
                    ),
                )
            with pytest.raises(
                BillingLimitError,
            ):
                await ctx.service.require_feature(
                    owner,
                    "sendingReportByEmail",
                )

    asyncio.run(
        run(),
    )


def test_report_jobs_count_each_completed_generation_once(
    tmp_path: Path,
    configuration: Configuration,
    app: FastAPI,
) -> None:
    from cryptography.fernet import Fernet

    from app.core.app_check.app_check import AppCheck
    from app.service.report.report_generation_cipher import ReportGenerationCipher
    from app.service.report.report_generation_jobs import ReportGenerationJobs
    from app.service.report.report_generation_store import ReportGenerationStore
    from app.service.report.report_generation_worker import ReportGenerationWorker

    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            identity = await ctx.service.register()
            owner = str(
                identity.ownerId,
            )
            async with ctx.database.session() as session, session.begin():
                session.add(
                    BillingSubscriptionDB(
                        id=str(
                            uuid4(),
                        ),
                        owner_id=owner,
                        source="yookassa",
                        external_id="quota-http-fixture",
                        plan_id="monthly",
                        entitlement="pro",
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
            container = app.state.container
            store = ReportGenerationStore(
                ctx.database,
                ReportGenerationCipher(
                    Fernet.generate_key().decode(),
                ),
                configuration.server.report_generation,
            )
            jobs = ReportGenerationJobs(
                store,
                container.report_generation,
                ctx.service,
            )
            app.state.container = replace(
                container,
                subscriptions=ctx.service,
                report_jobs=jobs,
            )
            app.dependency_overrides[AppCheck.verify] = lambda: None
            initial = (
                await ctx.service.status(
                    owner,
                )
            ).availableCountPerDay
            body = {
                "settingsAI": {},
                "examinationData": {
                    "usExaminationTypeId": "bladder",
                    "photos": [],
                    "examinationNumber": "TEST",
                    "patientName": "Test Patient",
                    "patientGender": "female",
                    "patientDateOfBirth": "1990-01-01T00:00:00Z",
                    "examinationDescription": "Findings",
                    "isPatientPreparedForExamination": True,
                    "isPatientConsent": True,
                },
            }
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(
                    app,
                ),
                base_url="https://api.example",
            ) as client:
                for _ in range(
                    2,
                ):
                    request = {
                        "requestId": str(
                            uuid4(),
                        ),
                        "examination": body,
                    }
                    headers = {"Authorization": "Bearer " + identity.accessToken}
                    response = await client.post(
                        "/v1/ultrasound/report_generations",
                        json=request,
                        headers=headers,
                    )
                    assert response.status_code == 202, response.text
                    job = await store.claim(
                        130,
                    )
                    assert job is not None
                    await ReportGenerationWorker(
                        Variables(
                            environment="development",
                            model_service_type="mock",
                        ),
                    ).execute(
                        job,
                        store,
                        container.report_generation,
                        container.model_service,
                        ctx.service,
                        10,
                    )
                    completed = await client.get(
                        "/v1/ultrasound/report_generations/" + job.id,
                        headers=headers,
                    )
                    assert completed.status_code == 200, completed.text
                    assert completed.json()["status"] == "completed", completed.text
                    duplicate = await client.post(
                        "/v1/ultrasound/report_generations",
                        json=request,
                        headers=headers,
                    )
                    assert duplicate.status_code == 202, duplicate.text
                    assert duplicate.json()["generationId"] == job.id
                    assert duplicate.json()["status"] == "completed"
            assert (
                await ctx.service.status(
                    owner,
                )
            ).availableCountPerDay == initial - 2
            async with ctx.database.session() as session:
                rows = list(
                    await session.scalars(
                        select(
                            BillingUsageDB,
                        ),
                    ),
                )
                assert (
                    len(
                        rows,
                    )
                    == 2
                    and len(
                        {row.id for row in rows},
                    )
                    == 2
                )
                assert all(
                    (row.owner_id == owner and row.status == "completed" for row in rows),
                )

    asyncio.run(
        run(),
    )


def test_checkout_webhook_renewal_and_refund(
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
                "apple-attribution-only",
            )
            with pytest.raises(
                BillingAccessDeniedError,
            ):
                await ctx.service.bind_checkout(
                    checkout.code,
                    None,
                )
            with pytest.raises(
                BillingPurchaseError,
            ):
                await ctx.service.start_checkout_payment(
                    browser,
                    is_auto_renewal_accepted=False,
                )
            url = await ctx.service.start_checkout_payment(
                browser,
                is_auto_renewal_accepted=True,
            )
            assert url == "https://yoomoney.ru/checkout/test"
            assert (
                await ctx.service.status(
                    owner,
                )
                is None
            )
            await ctx.service.start_checkout_payment(
                browser,
                is_auto_renewal_accepted=True,
            )
            assert (
                sum(
                    (request.method == "POST" for request in ctx.requests),
                )
                == 1
            )
            resumed = await ctx.service.create_checkout(
                owner,
                "monthly",
            )
            resumed_browser, _ = await ctx.service.bind_checkout(
                resumed.code,
                None,
            )
            assert (
                await ctx.service.start_checkout_payment(
                    resumed_browser,
                    is_auto_renewal_accepted=True,
                )
                == url
            )
            assert (
                len(
                    ctx.payments,
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
            await ctx.service.payment_notification(
                payment["id"],
            )
            first = await ctx.service.status(
                owner,
            )
            assert first.type == "pro" and first.isAutoRenewing
            await ctx.service.payment_notification(
                payment["id"],
            )
            assert (
                await ctx.service.status(
                    owner,
                )
            ).expiresAt == first.expiresAt
            await ctx.service.require_feature(
                owner,
                "sendingReportByEmail",
            )
            with pytest.raises(
                BillingConflictError,
            ):
                await ctx.service.create_checkout(
                    owner,
                    "monthly",
                )
            async with ctx.database.session() as session, session.begin():
                sub = await session.scalar(
                    select(
                        BillingSubscriptionDB,
                    ),
                )
                assert sub
                sub.next_charge_at = datetime.now(
                    UTC,
                ) - timedelta(
                    seconds=1,
                )
            await ctx.service.tick()
            await ctx.service.tick()
            assert (
                len(
                    ctx.payments,
                )
                == 2
            )
            renewal = list(
                ctx.payments.values(),
            )[1]
            renewal.update(
                status="succeeded",
                paid=True,
            )
            await ctx.service.payment_notification(
                renewal["id"],
            )
            assert (
                await ctx.service.status(
                    owner,
                )
            ).expiresAt > first.expiresAt
            renewal["refunded_amount"] = {"value": "100.00", "currency": "RUB"}
            await ctx.service.payment_notification(
                renewal["id"],
            )
            assert (
                await ctx.service.status(
                    owner,
                )
            ).expiresAt == first.expiresAt
            payment["refunded_amount"] = {"value": "100.00", "currency": "RUB"}
            await ctx.service.payment_notification(
                payment["id"],
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


@pytest.mark.parametrize(
    "field,value",
    [("amount", {"value": "0.01", "currency": "RUB"}), ("recipient", {"account_id": "other"})],
)
def test_payment_validation(
    tmp_path: Path,
    configuration: Configuration,
    field: str,
    value: object,
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
            await ctx.service.start_checkout_payment(
                browser,
                is_auto_renewal_accepted=True,
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
            payment[field] = value
            with pytest.raises(
                BillingPurchaseError,
            ):
                await ctx.service.payment_notification(
                    payment["id"],
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


@pytest.mark.parametrize(
    "environment",
    ["development", "production"],
)
@pytest.mark.parametrize(
    "is_payment_test",
    [True, False, None, 1, 0],
)
def test_canonical_payment_mode_must_match_environment(
    tmp_path: Path,
    configuration: Configuration,
    environment: Literal["development", "production"],
    is_payment_test: object,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
            environment=environment,
            is_live=environment == "production",
            is_live_enabled=True,
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
            await ctx.service.start_checkout_payment(
                browser,
                is_auto_renewal_accepted=True,
            )
            payment = next(
                iter(
                    ctx.payments.values(),
                ),
            )
            payment.update(
                status="succeeded",
                paid=True,
                test=is_payment_test,
            )
            if is_payment_test is (environment == "development"):
                await ctx.service.payment_notification(
                    payment["id"],
                )
                assert (
                    await ctx.service.status(
                        owner,
                    )
                    is not None
                )
            else:
                with pytest.raises(
                    BillingPurchaseError,
                ):
                    await ctx.service.payment_notification(
                        payment["id"],
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


def test_live_shop_is_rejected_before_charge(
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
            checkout = await ctx.service.create_checkout(
                owner,
                "monthly",
            )
            browser, _ = await ctx.service.bind_checkout(
                checkout.code,
                None,
            )
            with pytest.raises(
                BillingUnavailableError,
            ):
                await ctx.service.start_checkout_payment(
                    browser,
                    is_auto_renewal_accepted=True,
                )
            assert not ctx.payments
            assert not any(
                (request.method == "POST" for request in ctx.requests),
            )

    asyncio.run(
        run(),
    )


def test_cancellation_keeps_paid_period(
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
            await ctx.service.start_checkout_payment(
                browser,
                is_auto_renewal_accepted=True,
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
            await ctx.service.payment_notification(
                payment["id"],
            )
            previous = await ctx.service.status(
                owner,
            )
            async with ctx.database.session() as session, session.begin():
                subscription = await session.scalar(
                    select(
                        BillingSubscriptionDB,
                    ),
                )
                subscription.next_charge_at = datetime.now(
                    UTC,
                ) - timedelta(
                    seconds=1,
                )
            await ctx.service.tick()  # Persist a renewal, but do not dispatch it yet.
            await ctx.service.cancel(
                owner,
            )
            await ctx.service.tick()
            assert (
                len(
                    ctx.payments,
                )
                == 1
            )
            status = await ctx.service.status(
                owner,
            )
            assert status.expiresAt == previous.expiresAt and not status.isAutoRenewing
            assert status.type == "pro"

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "environment",
    [Environment.SANDBOX, Environment.PRODUCTION],
)
def test_apple_verification_restore_and_revocation(
    tmp_path: Path,
    configuration: Configuration,
    environment: Environment,
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
            current = SimpleNamespace(
                appAccountToken=owner,
                originalTransactionId="100001",
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
            renewal = SimpleNamespace(
                gracePeriodExpiresDate=None,
                autoRenewStatus=1,
            )
            ctx.apple.transaction.return_value = (current, environment)
            ctx.apple.current.return_value = (current, renewal)
            with pytest.raises(
                BillingPurchaseError,
            ):
                await ctx.service.sync_apple(
                    other,
                    "signed-proof",
                )
            await ctx.service.sync_apple(
                owner,
                "signed-proof",
            )
            status = await ctx.service.status(
                owner,
            )
            assert status is not None and status.type == "pro" and status.source == "apple"
            assert "appleEnvironment" not in status.model_dump()
            async with ctx.database.session() as session:
                recorded = await session.scalar(
                    select(
                        BillingSubscriptionDB,
                    ),
                )
                assert recorded is not None and recorded.apple_environment == environment.value
            restored = await ctx.service.sync_apple(
                other,
                "signed-proof",
            )
            assert (
                restored
                and str(
                    restored.ownerId,
                )
                == owner
            )
            assert (
                await ctx.service.authenticate(
                    restored.accessToken,
                )
                == owner
            )
            current.revocationDate = current.expiresDate - 1
            await ctx.service.sync_apple(
                owner,
                "signed-proof",
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


def test_application_billing_requires_app_check(
    variables: Variables,
) -> None:
    async def run() -> None:
        app = ApplicationFactory.create_main(
            variables,
        )
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(
                app,
            ),
            base_url="https://api.example",
        ) as client:
            for path in (
                "register",
                "status",
                "recover",
                "sync_apple",
                "prepare_payment",
                "tokenize_payment",
                "check_payment",
            ):
                response = await client.request(
                    "GET" if path == "status" else "POST",
                    "/v1/subscriptions/" + path,
                )
                assert response.status_code == 401

    asyncio.run(
        run(),
    )


def test_gateway_csrf_and_callback_not_trusted(
    tmp_path: Path,
    configuration: Configuration,
    variables: Variables,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            gateway = ApplicationFactory.create_payment(
                variables,
            )
            gateway.dependency_overrides[ServiceDependencies.subscriptions] = lambda: ctx.service
            # Bound gateway handlers resolve through the container as well as FastAPI dependencies.
            gateway.state.container = SimpleNamespace(
                subscriptions=ctx.service,
                configuration=configuration,
            )
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(
                    gateway,
                ),
                base_url="https://pay.example",
            ) as client:
                response = await client.post(
                    "/pay/bind",
                    data={"csrf": "forged", "code": "00000000"},
                )
                assert response.status_code == 401
                response = await client.get(
                    "/pay/complete",
                )
                assert response.status_code == 200 and "no-store" in response.headers["cache-control"]
                assert not ctx.payments
                ctx.apple.notification.side_effect = BillingPurchaseError()
                response = await client.post(
                    "/webhooks/apple",
                    json={"signedPayload": "forged"},
                )
                assert response.status_code == 400

    asyncio.run(
        run(),
    )


def test_billing_api_requires_owner_secret(
    tmp_path: Path,
    configuration: Configuration,
    variables: Variables,
) -> None:
    from app.core.app_check.app_check import AppCheck

    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            app = ApplicationFactory.create_main(
                variables,
            )
            app.state.container = SimpleNamespace(
                subscriptions=ctx.service,
                configuration=configuration,
            )
            app.dependency_overrides[AppCheck.verify] = lambda: None
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(
                    app,
                ),
                base_url="https://api.example",
            ) as client:
                identity = (
                    await client.post(
                        "/v1/subscriptions/register",
                    )
                ).json()
                assert (
                    await client.get(
                        "/v1/subscriptions/status",
                    )
                ).status_code == 401
                headers = {"Authorization": "Bearer " + identity["accessToken"]}
                status = await client.get(
                    "/v1/subscriptions/status",
                    headers=headers,
                )
                assert status.status_code == 200 and status.json() is None
                assert (
                    await client.get(
                        "/v1/subscriptions/status",
                        headers={"Authorization": "Bearer " + identity["ownerId"]},
                    )
                ).status_code == 401
                checkout = await client.post(
                    "/v1/subscriptions/checkout",
                    headers=headers,
                    json={"planId": "monthly"},
                )
                assert (
                    checkout.status_code == 200
                    and len(
                        checkout.json()["code"],
                    )
                    == 8
                )
                key = (
                    await client.post(
                        "/v1/subscriptions/recovery_key",
                        headers=headers,
                    )
                ).json()["recoveryKey"]
                restored = (
                    await client.post(
                        "/v1/subscriptions/recover",
                        json={"recoveryKey": key},
                    )
                ).json()
                assert restored["ownerId"] == identity["ownerId"] and restored["accessToken"] != identity["accessToken"]

    asyncio.run(
        run(),
    )


def test_gateway_fetches_provider_before_granting(
    tmp_path: Path,
    configuration: Configuration,
    variables: Variables,
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
            await ctx.service.start_checkout_payment(
                browser,
                is_auto_renewal_accepted=True,
            )
            payment = next(
                iter(
                    ctx.payments.values(),
                ),
            )
            gateway = ApplicationFactory.create_payment(
                variables,
            )
            gateway.state.container = SimpleNamespace(
                subscriptions=ctx.service,
                configuration=configuration,
            )
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(
                    gateway,
                ),
                base_url="https://pay.example",
            ) as client:
                response = await client.post(
                    "/webhooks/yookassa",
                    json={
                        "event": "payment.succeeded",
                        "object": {"id": payment["id"], "status": "succeeded", "paid": True},
                    },
                )
                assert response.status_code == 200
                assert (
                    await ctx.service.status(
                        owner,
                    )
                    is None
                )
                payment.update(
                    status="succeeded",
                    paid=True,
                )
                response = await client.post(
                    "/webhooks/yookassa",
                    json={"event": "payment.succeeded", "object": {"id": payment["id"]}},
                )
                assert response.status_code == 200
                assert (
                    await ctx.service.status(
                        owner,
                    )
                ).type == "pro"
                malformed = await client.post(
                    "/webhooks/yookassa",
                    content="{invalid",
                )
                assert malformed.status_code == 400

    asyncio.run(
        run(),
    )
