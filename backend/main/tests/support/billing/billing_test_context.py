from __future__ import annotations

import base64
import json
import os
from contextlib import AbstractAsyncContextManager
from pathlib import Path
from types import TracebackType
from typing import Any, Literal
from unittest.mock import Mock
from urllib.parse import parse_qs
from uuid import uuid4

import httpx
from sqlalchemy import text
from sqlalchemy.schema import CreateSchema, DropSchema

from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.database.billing_base import BillingBase
from app.database.billing_database import BillingDatabase
from app.service.billing.apple_subscription_verifier import AppleSubscriptionVerifier
from app.service.billing.checkout_payment_service import CheckoutPaymentService
from app.service.billing.subscription_service import SubscriptionService
from tests.support.billing.billing_test_robokassa_provider import BillingTestRobokassaProvider


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
            report_generation_encryption_key=base64.urlsafe_b64encode(
                bytes(
                    32,
                ),
            ).decode(),
            config_dir=directory,
            robokassa_merchant_login="123",
            robokassa_password1="test_password1",
            robokassa_password2="test_password2",
            robokassa_password3="test_password3",
            is_robokassa_live_enabled=is_live_enabled,
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
            BillingTestRobokassaProvider(
                self.client,
                self.variables,
                configuration.server.billing.provider,
            ),
            self.apple,
        )

        self.checkout = CheckoutPaymentService(
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
        if request.url.host == "canonical.example":
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
                None,
            )
            return httpx.Response(
                200,
                json=payment
                or {
                    "id": request.url.path.rsplit(
                        "/",
                        1,
                    )[-1],
                    "status": "pending",
                },
            )
        if request.url.path.endswith(
            "/GetState",
        ):
            item = self.refunds[request.url.params["id"]]
            return httpx.Response(
                200,
                json={
                    "requestId": item["id"],
                    "amount": item["amount"]["value"],
                    "label": {"succeeded": "finished", "pending": "processing", "canceled": "canceled"}[item["status"]],
                },
            )
        if request.url.path.endswith(
            "/Create",
        ):
            payload = self.decode_payload(
                request,
            )
            identifier = str(
                uuid4(),
            )
            self.refunds[identifier] = {
                "id": identifier,
                "amount": {
                    "value": str(
                        payload["RefundSum"],
                    ),
                    "currency": "RUB",
                },
                "status": "pending",
            }
            return httpx.Response(
                200,
                json={"success": True, "requestId": identifier},
            )
        if request.url.path.endswith(
            "/Recurring",
        ):
            fields = {
                key: value[0]
                for key, value in parse_qs(
                    request.content.decode(),
                ).items()
            }
            key, invoice, amount = fields["Shp_order_id"], fields["InvoiceID"], fields["OutSum"]
        else:
            payload = self.decode_payload(
                request,
            )
            if request.url.path.endswith(
                "/DeactivateInvoice",
            ):
                payment = next(
                    (
                        value
                        for value in self.payments.values()
                        if value["id"]
                        == str(
                            payload["InvId"],
                        )
                    ),
                )
                payment["invoice_status"] = "Expired"
                return httpx.Response(
                    200,
                    json={"isSuccess": True},
                )
            if request.url.path.endswith(
                "/GetInvoiceInformation",
            ):
                payment = next(
                    (
                        value
                        for value in self.payments.values()
                        if value["id"]
                        == str(
                            payload["InvId"],
                        )
                    ),
                    None,
                )
                return httpx.Response(
                    200,
                    json={
                        "isSuccess": True,
                        "invoiceInformation": {
                            "invId": payload["InvId"],
                            "invoiceStatus": payment.get(
                                "invoice_status",
                                "Paid" if payment["status"] == "succeeded" else "NotPaid",
                            ),
                            "payments": [{"state": "processing"}]
                            if payment.get(
                                "is_processing",
                            )
                            else [],
                            "invoicePaymentUrl": "https://auth.robokassa.ru/merchant/Invoice/test",
                        },
                    }
                    if payment
                    else {"isSuccess": False},
                )
            key, invoice, amount = (
                payload["UserFields"]["Shp_order_id"],
                str(
                    payload["InvId"],
                ),
                payload["OutSum"],
            )
        if key not in self.payments:
            self.payments[key] = {
                "id": invoice,
                "status": "pending",
                "paid": False,
                "test": not self.is_live,
                "amount": {"value": amount, "currency": "RUB"},
                "metadata": {"order_id": key},
                "recipient": {"account_id": "123"},
                "payment_method": {"id": invoice, "saved": True, "type": "bank_card"},
                "op_key": "operation-" + invoice,
                "confirmation": {"confirmation_url": "https://auth.robokassa.ru/merchant/Invoice/test"},
            }
        if request.url.path.endswith(
            "/Recurring",
        ):
            return httpx.Response(
                200,
                text="OK",
            )
        return httpx.Response(
            200,
            json={
                "isSuccess": True,
                "id": str(
                    uuid4(),
                ),
                "invId": int(
                    invoice,
                ),
                "url": "https://auth.robokassa.ru/merchant/Invoice/test",
            },
        )

    @staticmethod
    def decode_payload(
        request: httpx.Request,
    ) -> dict[str, Any]:
        token = json.loads(
            request.content,
        )
        return json.loads(
            base64.urlsafe_b64decode(
                token.split(
                    ".",
                )[1]
                + "==",
            ),
        )
