from __future__ import annotations

import json
import os
from contextlib import AbstractAsyncContextManager
from pathlib import Path
from types import TracebackType
from typing import Any, Literal
from unittest.mock import Mock
from uuid import uuid4

import httpx
from sqlalchemy import text
from sqlalchemy.schema import CreateSchema, DropSchema

from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.database.billing_base import BillingBase
from app.database.billing_database import BillingDatabase
from app.service.billing.apple_subscription_verifier import AppleSubscriptionVerifier
from app.service.billing.sdk_payment_service import SDKPaymentService
from app.service.billing.subscription_service import SubscriptionService
from app.service.billing.yookassa_payment_provider import YooKassaPaymentProvider


class BillingTestContext(AbstractAsyncContextManager["BillingTestContext"]):
    def __init__(
        self,
        directory: Path,
        configuration: Configuration,
        *,
        is_live: bool = False,
        environment: Literal["development", "production"] = "development",
        is_live_enabled: bool = False,
        catalog: dict[str, Any] | None = None,
    ) -> None:
        catalog_dir = directory / environment
        catalog_dir.mkdir(
            parents=True,
            exist_ok=True,
        )
        (catalog_dir / "billing.json").write_text(
            json.dumps(
                catalog
                if catalog is not None
                else {
                    "termsVersion": "test-v1",
                    "tiers": [
                        {
                            "id": "pro",
                            "titleLocaleKey": "paywallProLabel",
                            "featureLocaleKeys": ["paywallProModelsDescription"],
                        }
                    ],
                    "products": [
                        {
                            "id": identifier,
                            "period": "monthly",
                            "entitlement": "pro",
                            "titleLocaleKey": "subscriptionProMonthlyLabel",
                            "priceTemplateLocaleKey": "subscriptionMonthlyPriceDescription",
                            "price": {"amountMinor": 10000, "currencyIso2Code": "RUB"},
                        }
                        for identifier in ("monthly", "test.monthly")
                    ],
                },
            ),
        )
        self.variables = Variables(
            environment=environment,
            config_dir=directory,
            yookassa_shop_id="123",
            yookassa_secret_key="test_secret",
            yookassa_client_application_key="test_public_key",
            billing_public_url="https://pay.example/pay",
            is_yookassa_live_enabled=is_live_enabled,
            is_apple_sandbox_allowed=True,
        )
        database_url = os.environ.get(
            "DOGLYAD_TEST_POSTGRES_URL",
            "sqlite+aiosqlite://",
        )
        self.database = BillingDatabase(
            database_url,
        )
        self._schema = (
            "doglyad_test_" + uuid4().hex
            if database_url.startswith(
                "postgresql+",
            )
            else None
        )
        if self._schema:
            self.database.engine.update_execution_options(
                schema_translate_map={None: self._schema},
            )
        self.payments: dict[str, dict[str, Any]] = {}
        self.refunds: dict[str, dict[str, Any]] = {}
        self.requests: list[httpx.Request] = []
        self.is_live = is_live
        self.client = httpx.AsyncClient(
            transport=httpx.MockTransport(
                self._respond,
            ),
        )
        self.apple = Mock(
            spec=AppleSubscriptionVerifier,
        )
        self.apple.owner_id = AppleSubscriptionVerifier.owner_id
        self.service = SubscriptionService(
            self.database,
            configuration,
            self.variables,
            YooKassaPaymentProvider(
                self.client,
                self.variables,
                configuration.server.billing.provider,
            ),
            self.apple,
        )

        self.sdk = SDKPaymentService(
            self.service,
            configuration,
            self.variables,
        )

    async def __aenter__(
        self,
    ) -> BillingTestContext:
        async with self.database.engine.begin() as connection:
            if self._schema:
                await connection.execute(
                    CreateSchema(
                        self._schema,
                    ),
                )
            else:
                await connection.execute(
                    text(
                        "PRAGMA foreign_keys=ON",
                    ),
                )
            await connection.run_sync(
                BillingBase.metadata.create_all,
            )
        return self

    async def __aexit__(
        self,
        exc_type: type[BaseException] | None,
        exc_value: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        await self.client.aclose()
        if self._schema:
            async with self.database.engine.begin() as connection:
                await connection.execute(
                    DropSchema(
                        self._schema,
                        cascade=True,
                    ),
                )
        await self.database.close()

    def _respond(
        self,
        request: httpx.Request,
    ) -> httpx.Response:
        self.requests.append(
            request,
        )
        if request.url.path == "/v3/me":
            return httpx.Response(
                200,
                json={"account_id": "123", "test": not self.is_live, "status": "enabled"},
            )
        if request.url.path == "/v3/refunds" and request.method == "GET":
            return httpx.Response(
                200,
                json={
                    "type": "list",
                    "items": [
                        item for item in self.refunds.values() if item["payment_id"] == request.url.params["payment_id"]
                    ],
                },
            )
        if request.method == "POST":
            payload = json.loads(
                request.content,
            )
            key = request.headers["Idempotence-Key"]
            if key not in self.payments:
                self.payments[key] = {
                    "id": str(
                        uuid4(),
                    ),
                    "status": "pending",
                    "paid": False,
                    "test": not self.is_live,
                    "amount": payload["amount"],
                    "metadata": payload["metadata"],
                    "recipient": {"account_id": "123"},
                    "payment_method": {"id": "saved-method", "saved": True, "type": "bank_card"},
                    "confirmation": {"confirmation_url": "https://yoomoney.ru/checkout/test"},
                }
            return httpx.Response(
                200,
                json=self.payments[key],
            )
        payment = next(
            (
                value
                for value in self.payments.values()
                if value["id"]
                == request.url.path.rsplit(
                    "/",
                    1,
                )[-1]
            ),
        )
        return httpx.Response(
            200,
            json=payment,
        )
