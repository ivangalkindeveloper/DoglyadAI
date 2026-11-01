from __future__ import annotations

import asyncio
import json
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import httpx
import pytest
from appstoreserverlibrary.models.Environment import Environment
from fastapi import FastAPI
from pydantic import ValidationError
from sqlalchemy import select

from app.core.application.service_dependencies import ServiceDependencies
from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.database.billing_payment_db import BillingPaymentDB
from app.error.billing_purchase_error import BillingPurchaseError
from app.model.billing.billing_catalog import BillingCatalog
from app.model.billing.billing_period import BillingPeriod
from app.model.billing.billing_tokenize_payment_request import BillingTokenizePaymentRequest
from app.service.billing.subscription_service import SubscriptionService
from tests.support.billing.billing_test_context import BillingTestContext


def catalog_for(
    period: BillingPeriod,
) -> dict[str, Any]:
    return {
        "termsVersion": "test-v1",
        "tiers": [
            {"id": "pro", "titleLocaleKey": "paywallProLabel", "featureLocaleKeys": ["paywallProModelsDescription"]}
        ],
        "products": [
            {
                "id": "test-yoo",
                "period": period.value,
                "entitlement": "pro",
                "titleLocaleKey": "subscriptionProMonthlyLabel",
                "priceTemplateLocaleKey": "subscriptionMonthlyPriceDescription",
                "price": {"amountMinor": 10000, "currencyIso2Code": "RUB"},
            }
        ],
    }


@pytest.mark.parametrize(
    "field",
    ["titleLocaleKey", "priceTemplateLocaleKey"],
)
def test_missing_product_translation_prevents_billing_startup(
    tmp_path: Path,
    configuration: Configuration,
    field: str,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            catalog = catalog_for(
                BillingPeriod.MONTHLY,
            )
            catalog["products"][0][field] = "missingBillingTestLabel"
            (ctx.variables.configuration_directory / "billing.json").write_text(
                json.dumps(
                    catalog,
                ),
            )
            with pytest.raises(
                ValueError,
                match="Missing localization key",
            ):
                SubscriptionService(
                    ctx.database,
                    configuration,
                    ctx.variables,
                    ctx.service._yookassa,
                    ctx.apple,
                )

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "template",
    ["per month", "{price:.2f}", "{price} {value}", "{{price}}"],
)
def test_invalid_localized_price_template_prevents_billing_startup(
    tmp_path: Path,
    configuration: Configuration,
    template: str,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            localized = configuration.l10n.model_copy(
                deep=True,
            )
            localized.root[LanguageCode.RU]["subscriptionMonthlyPriceDescription"] = template
            invalid = replace(
                configuration,
                l10n=localized,
            )
            with pytest.raises(
                ValueError,
                match="exactly one",
            ):
                SubscriptionService(
                    ctx.database,
                    invalid,
                    ctx.variables,
                    ctx.service._yookassa,
                    ctx.apple,
                )

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "language",
    list(
        LanguageCode,
    ),
)
def test_shared_catalog_and_endpoint_remains_protected(
    tmp_path: Path,
    configuration: Configuration,
    app: FastAPI,
    language: LanguageCode,
) -> None:
    from app.core.app_check.app_check import AppCheck

    async def run() -> None:
        directory = (
            Path(
                __file__,
            )
            .resolve()
            .parents[1]
            / "config"
        )
        development = json.loads(
            (directory / "development/billing.json").read_text(),
        )
        production = json.loads(
            (directory / "production/billing.json").read_text(),
        )
        assert development == production
        async with BillingTestContext(
            tmp_path,
            configuration,
            catalog=development,
        ) as ctx:
            app.dependency_overrides[ServiceDependencies.subscriptions] = lambda: ctx.service
            app.dependency_overrides[AppCheck.verify] = lambda: None
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(
                    app=app,
                ),
                base_url="https://test",
            ) as client:
                response = await client.get(
                    "/v1/subscriptions/plans",
                    headers={"Accept-Language": language.value},
                )
                assert response.status_code == 200
                data = response.json()
                expected = {
                    f"{tier}_{period}"
                    for tier in ("base", "pro")
                    for period in ("weekly", "monthly", "six_months", "annual")
                }
                assert set(
                    data,
                ) == {"tiers", "products"}
                assert {product["id"] for product in data["products"]} == expected
                for tier, configured in zip(
                    data["tiers"],
                    development["tiers"],
                    strict=True,
                ):
                    assert set(
                        tier,
                    ) == {"id", "title", "features"}
                    assert tier["id"] == configured["id"]
                    assert tier["title"] == configuration.text(
                        language,
                        configured["titleLocaleKey"],
                    )
                    assert tier["features"] == [
                        configuration.text(
                            language,
                            key,
                        )
                        for key in configured["featureLocaleKeys"]
                    ]
                for product in data["products"]:
                    configured = next(
                        (item for item in development["products"] if item["id"] == product["id"]),
                    )
                    assert product["title"] == configuration.text(
                        language,
                        configured["titleLocaleKey"],
                    )
                    assert product["priceTemplate"] == configuration.text(
                        language,
                        configured["priceTemplateLocaleKey"],
                    )
                    assert set(
                        product,
                    ) == {"id", "entitlement", "period", "price", "title", "priceTemplate"}
                    assert product["price"]["amountMinor"] > 0
                    assert product["price"]["currencyIso2Code"] == "RUB"
                    assert (
                        product["entitlement"]
                        == product["id"].split(
                            "_",
                        )[0]
                    )
                    if product["id"].endswith(
                        "six_months",
                    ):
                        assert product["period"] == "sixMonth"
                app.dependency_overrides.pop(
                    AppCheck.verify,
                    None,
                )
                assert (
                    await client.get(
                        "/v1/subscriptions/plans",
                    )
                ).status_code == 401

    asyncio.run(
        run(),
    )


def test_removing_product_stops_new_purchases(
    tmp_path: Path,
    configuration: Configuration,
) -> None:
    async def run() -> None:
        catalog = catalog_for(
            BillingPeriod.MONTHLY,
        )
        catalog["products"] = []
        async with BillingTestContext(
            tmp_path,
            configuration,
            catalog=catalog,
        ) as ctx:
            plans = ctx.service.plans(
                LanguageCode.EN,
            )
            assert plans.products == []
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            with pytest.raises(
                BillingPurchaseError,
            ):
                await ctx.sdk.prepare(
                    owner,
                    "test-yoo",
                    LanguageCode.EN,
                )
            with pytest.raises(
                BillingPurchaseError,
            ):
                await ctx.service.create_checkout(
                    owner,
                    "test-yoo",
                )
            assert ctx.requests == []

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "case",
    ["duplicate", "missing", "empty_features"],
)
def test_invalid_tier_metadata_is_rejected(
    case: str,
) -> None:
    catalog = catalog_for(
        BillingPeriod.MONTHLY,
    )
    if case == "duplicate":
        catalog["tiers"].append(
            catalog["tiers"][0].copy(),
        )
    elif case == "missing":
        catalog["tiers"] = []
    else:
        catalog["tiers"][0]["featureLocaleKeys"] = []
    with pytest.raises(
        ValidationError,
    ):
        BillingCatalog.model_validate(
            catalog,
        )


@pytest.mark.parametrize(
    "field",
    ["titleLocaleKey", "featureLocaleKeys"],
)
def test_missing_tier_translation_prevents_billing_startup(
    tmp_path: Path,
    configuration: Configuration,
    field: str,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            catalog = catalog_for(
                BillingPeriod.MONTHLY,
            )
            catalog["tiers"][0][field] = ["missingTierLabel"] if field == "featureLocaleKeys" else "missingTierLabel"
            (ctx.variables.configuration_directory / "billing.json").write_text(
                json.dumps(
                    catalog,
                ),
            )
            with pytest.raises(
                ValueError,
                match="Missing localization key",
            ):
                SubscriptionService(
                    ctx.database,
                    configuration,
                    ctx.variables,
                    ctx.service._yookassa,
                    ctx.apple,
                )

    asyncio.run(
        run(),
    )


def test_duplicate_product_identifiers_are_rejected() -> None:
    catalog = catalog_for(
        BillingPeriod.MONTHLY,
    )
    catalog["products"].append(
        catalog["products"][0].copy(),
    )
    with pytest.raises(
        ValidationError,
    ):
        BillingCatalog.model_validate(
            catalog,
        )


@pytest.mark.parametrize(
    "price",
    [
        {"amountMinor": 0, "currencyIso2Code": "RUB"},
        {"amountMinor": 100.5, "currencyIso2Code": "RUB"},
        {"amountMinor": 100, "currencyIso2Code": "USD"},
        {"amountMinor": 100},
        {"amountMinor": 100, "currency": "RUB"},
    ],
)
def test_catalog_rejects_invalid_or_legacy_price(
    price: dict[str, Any],
) -> None:
    catalog = catalog_for(
        BillingPeriod.MONTHLY,
    )
    catalog["products"][0]["price"] = price
    with pytest.raises(
        ValidationError,
    ):
        BillingCatalog.model_validate(
            catalog,
        )


@pytest.mark.parametrize(
    ("period", "first_until", "second_until"),
    [
        (
            BillingPeriod.WEEKLY,
            datetime(
                2026,
                2,
                7,
                12,
                tzinfo=UTC,
            ),
            datetime(
                2026,
                2,
                14,
                12,
                tzinfo=UTC,
            ),
        ),
        (
            BillingPeriod.MONTHLY,
            datetime(
                2026,
                2,
                28,
                12,
                tzinfo=UTC,
            ),
            datetime(
                2026,
                3,
                28,
                12,
                tzinfo=UTC,
            ),
        ),
        (
            BillingPeriod.SIX_MONTH,
            datetime(
                2026,
                7,
                31,
                12,
                tzinfo=UTC,
            ),
            datetime(
                2027,
                1,
                31,
                12,
                tzinfo=UTC,
            ),
        ),
        (
            BillingPeriod.ANNUAL,
            datetime(
                2027,
                1,
                31,
                12,
                tzinfo=UTC,
            ),
            datetime(
                2028,
                1,
                31,
                12,
                tzinfo=UTC,
            ),
        ),
    ],
)
def test_sdk_and_renewal_keep_paid_period_and_price_snapshot(
    tmp_path: Path,
    configuration: Configuration,
    monkeypatch: pytest.MonkeyPatch,
    period: BillingPeriod,
    first_until: datetime,
    second_until: datetime,
) -> None:
    async def run() -> None:
        now = datetime(
            2026,
            1,
            31,
            12,
            tzinfo=UTC,
        )
        async with BillingTestContext(
            tmp_path,
            configuration,
            catalog=catalog_for(
                period,
            ),
        ) as ctx:
            monkeypatch.setattr(
                ctx.service,
                "_now",
                lambda: now,
            )
            monkeypatch.setattr(
                ctx.sdk,
                "_now",
                lambda: now,
            )
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            prepared = await ctx.sdk.prepare(
                owner,
                "test-yoo",
                LanguageCode.EN,
            )
            label = configuration.application_localizations[LanguageCode.EN].strings[period.locale_key]
            assert label in prepared.description
            await ctx.sdk.tokenize(
                owner,
                BillingTokenizePaymentRequest(
                    paymentId=prepared.payment.id,
                    paymentToken="test-token",
                    termsVersion=prepared.termsVersion,
                    isAutoRenewalAccepted=True,
                ),
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
            status = await ctx.service.status(
                owner,
            )
            assert status is not None and status.expiresAt == first_until
            # Changing the catalog cannot alter a previously agreed renewal period or amount.
            changed_catalog = catalog_for(
                BillingPeriod.ANNUAL,
            )
            changed_catalog["products"][0]["price"]["amountMinor"] = 999999
            changed_catalog["products"][0]["id"] = "new-plan"
            ctx.service._catalog = BillingCatalog.model_validate(
                changed_catalog,
            )
            now = first_until
            await ctx.service.tick()
            async with ctx.database.session() as session:
                renewal = await session.scalar(
                    select(
                        BillingPaymentDB,
                    ).where(
                        BillingPaymentDB.subscription_id.is_not(
                            None,
                        ),
                    ),
                )
                assert renewal is not None and renewal.amount_minor == 10000
                assert (renewal.interval_months, renewal.interval_days) == (
                    period.interval_months,
                    period.interval_days,
                )
            await ctx.service.tick()
            renewal_payment = next(
                (value for value in ctx.payments.values() if value["id"] != payment["id"]),
            )
            renewal_payment.update(
                status="succeeded",
                paid=True,
            )
            await ctx.service.payment_notification(
                renewal_payment["id"],
            )
            renewed = await ctx.service.status(
                owner,
            )
            assert renewed is not None and renewed.expiresAt == second_until
            assert (
                len(
                    ctx.payments,
                )
                == 2
            )

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "period",
    list(
        BillingPeriod,
    ),
)
def test_browser_checkout_snapshots_each_period(
    tmp_path: Path,
    configuration: Configuration,
    period: BillingPeriod,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
            catalog=catalog_for(
                period,
            ),
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            checkout = await ctx.service.create_checkout(
                owner,
                "test-yoo",
            )
            browser, _ = await ctx.service.bind_checkout(
                checkout.code,
                None,
            )
            await ctx.service.start_checkout_payment(
                browser,
                is_auto_renewal_accepted=True,
            )
            async with ctx.database.session() as session:
                order = await session.scalar(
                    select(
                        BillingPaymentDB,
                    ),
                )
                assert order is not None
                assert (order.interval_months, order.interval_days) == (period.interval_months, period.interval_days)

    asyncio.run(
        run(),
    )


def test_retired_apple_product_restores_only_an_existing_verified_subscription(
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
            other = str(
                (await ctx.service.register()).ownerId,
            )
            current = SimpleNamespace(
                appAccountToken=owner,
                originalTransactionId="retired-original",
                productId="test.monthly",
                expiresDate=int(
                    (
                        datetime.now(
                            UTC,
                        )
                        + timedelta(
                            days=10,
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
            ctx.apple.transaction.return_value = (current, Environment.SANDBOX)
            ctx.apple.current.return_value = (current, renewal)
            await ctx.service.sync_apple(
                owner,
                "verified-transaction",
            )
            ctx.service._catalog = ctx.service._catalog.model_copy(
                update={"products": []},
            )
            assert (
                ctx.service.plans(
                    LanguageCode.EN,
                ).products
                == []
            )
            restored = await ctx.service.sync_apple(
                other,
                "verified-transaction",
            )
            assert restored is not None and restored.ownerId == identity.ownerId
            assert (
                await ctx.service.authenticate(
                    restored.accessToken,
                )
                == owner
            )
            status = await ctx.service.status(
                owner,
            )
            assert status is not None and status.type == "pro"
            current.originalTransactionId = "unrecorded-original"
            with pytest.raises(
                BillingPurchaseError,
            ):
                await ctx.service.sync_apple(
                    owner,
                    "verified-transaction",
                )
            current.originalTransactionId = "retired-original"
            current.productId = "unrecognized-change"
            with pytest.raises(
                BillingPurchaseError,
            ):
                await ctx.service.sync_apple(
                    owner,
                    "verified-transaction",
                )
            current.productId = "test.monthly"
            current.revocationDate = int(
                datetime.now(
                    UTC,
                ).timestamp()
                * 1000,
            )
            await ctx.service.sync_apple(
                owner,
                "verified-transaction",
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
