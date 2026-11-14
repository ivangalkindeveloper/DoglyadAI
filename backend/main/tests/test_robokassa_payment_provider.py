from __future__ import annotations

import asyncio
import base64
import hashlib
import hmac
import json
from unittest.mock import patch

import httpx
import pytest

from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.error.billing_payment_error import BillingPaymentError
from app.error.billing_purchase_error import BillingPurchaseError
from app.error.billing_unavailable_error import BillingUnavailableError
from app.service.billing.robokassa_payment_provider import RobokassaPaymentProvider


def test_invoice_uses_server_signature_and_environment_credentials(
    configuration: Configuration,
) -> None:
    async def run() -> None:
        requests: list[httpx.Request] = []

        def respond(
            request: httpx.Request,
        ) -> httpx.Response:
            requests.append(
                request,
            )
            token = json.loads(
                request.content,
            )
            header, body, signature = token.split(
                ".",
            )
            actual = base64.urlsafe_b64decode(
                signature + "==",
            )
            assert hmac.compare_digest(
                actual,
                hmac.new(
                    b"shop:test-first",
                    (header + "." + body).encode(),
                    "sha256",
                ).digest(),
            )
            payload = json.loads(
                base64.urlsafe_b64decode(
                    body + "==",
                ),
            )
            assert payload["InvId"] == 123 and payload["OutSum"] == "100.25"
            assert payload["AdditionalParameters"] == {"IsTest": "1", "Recurring": "true", "Email": "buyer@example.com"}
            assert payload["Aliases"] == ["BankCard"]
            assert payload["InvoiceItems"][0]["Name"] == "Doglyad Pro monthly"
            return httpx.Response(
                200,
                json={
                    "isSuccess": True,
                    "id": "invoice-uuid",
                    "invId": 123,
                    "url": "https://auth.robokassa.ru/merchant/Invoice/test",
                },
            )

        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
        ) as client:
            provider = RobokassaPaymentProvider(
                client,
                Variables(
                    environment="development",
                    robokassa_merchant_login="shop",
                    robokassa_password1="test-first",
                    robokassa_password2="test-second",
                ),
                configuration.server.billing.provider,
            )
            result = await provider.create(
                "order",
                {
                    "invoice_id": "123",
                    "amount": {"value": "100.25", "currency": "RUB"},
                    "description": "Doglyad Pro monthly",
                    "email": "buyer@example.com",
                    "expires_at": "2026-11-20T10:00:00+00:00",
                },
            )
            assert result["status"] == "pending" and result["paid"] is False
            assert (
                len(
                    requests,
                )
                == 1
            )
            assert await provider.payment(
                "123",
            ) == provider._pending(
                "123",
            )
            assert (
                len(
                    requests,
                )
                == 1
            )  # Test payments must never query production OpStateExt.

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "state,expected",
    [("5", "pending"), ("10", "canceled"), ("50", "pending"), ("80", "pending"), ("100", "succeeded")],
)
def test_canonical_state_controls_access(
    configuration: Configuration,
    state: str,
    expected: str,
) -> None:
    async def run() -> None:
        def respond(
            request: httpx.Request,
        ) -> httpx.Response:
            assert request.url.path.endswith(
                "/OpStateExt",
            )
            return httpx.Response(
                200,
                text=f'<OperationStateResponse xmlns="http://merchant.roboxchange.com/WebService/"><Result><Code>0</Code></Result><State><Code>{state}</Code></State><Info><OutCurrLabel>RUR</OutCurrLabel><OutSum>100.250000</OutSum><OpKey>op</OpKey></Info></OperationStateResponse>',
            )

        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
        ) as client:
            provider = RobokassaPaymentProvider(
                client,
                Variables(
                    environment="production",
                    robokassa_merchant_login="shop",
                    robokassa_password1="first",
                    robokassa_password2="second",
                ),
                configuration.server.billing.provider,
            )
            result = await provider.payment(
                "123",
            )
            assert result["status"] == expected and result["paid"] is (state == "100")
            if state == "100":
                assert result["op_key"] == "op" and result["amount"] == {"value": "100.250000", "currency": "RUB"}

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "amount",
    ["NaN", "Infinity", "-1", "0.001", "not-a-number"],
)
def test_notification_rejects_invalid_signature_before_parsing_money(
    configuration: Configuration,
    amount: str,
) -> None:
    provider = RobokassaPaymentProvider(
        httpx.AsyncClient(),
        Variables(
            environment="development",
            robokassa_merchant_login="shop",
            robokassa_password1="first",
            robokassa_password2="second",
        ),
        configuration.server.billing.provider,
    )
    with patch.object(
        provider,
        "money_minor",
    ) as parse_money:
        with pytest.raises(
            BillingPurchaseError,
        ):
            provider.verify_notification(
                {"InvId": "123", "OutSum": amount, "SignatureValue": "forged"},
            )
        parse_money.assert_not_called()


@pytest.mark.parametrize(
    "amount,expected",
    [("0", 0), ("0.01", 1), ("100.250000", 10025), ("1e2", 10000), ("21474836.47", 2147483647)],
)
def test_money_minor_preserves_exact_values_within_ledger_range(
    amount: str,
    expected: int,
) -> None:
    assert (
        RobokassaPaymentProvider.money_minor(
            amount,
        )
        == expected
    )


@pytest.mark.parametrize(
    "amount",
    [
        "NaN",
        "Infinity",
        "-1",
        "0.001",
        "not-a-number",
        "1e999997",
        "1e-999997",
        "1e-999999999",
        "21474836.48",
        "1.0000000000000000000000000001",
        "0" * 65,
    ],
)
def test_money_minor_rejects_unbounded_or_inexact_values(
    amount: str,
) -> None:
    with pytest.raises(
        BillingPurchaseError,
    ):
        RobokassaPaymentProvider.money_minor(
            amount,
        )


def test_notification_signature_preserves_raw_decimal_and_sorted_user_fields(
    configuration: Configuration,
) -> None:
    async def run() -> None:
        async with httpx.AsyncClient() as client:
            provider = RobokassaPaymentProvider(
                client,
                Variables(
                    environment="development",
                    robokassa_merchant_login="shop",
                    robokassa_password1="first",
                    robokassa_password2="second",
                ),
                configuration.server.billing.provider,
            )
            signature = hashlib.sha256(
                b"100.000000:123:second:Shp_a=one:Shp_z=two",
            ).hexdigest()
            fields = {
                "InvId": "123",
                "OutSum": "100.000000",
                "Shp_z": "two",
                "Shp_a": "one",
                "SignatureValue": signature.upper(),
            }
            provider.verify_notification(
                fields,
            )
            with pytest.raises(
                BillingPurchaseError,
            ):
                provider.verify_notification(
                    {**fields, "SignatureValue": "не подпись"},
                )
            with pytest.raises(
                BillingPurchaseError,
            ):
                provider.verify_notification(
                    {**fields, "OutSum": "100.00"},
                )

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "response",
    [
        '<!DOCTYPE x [<!ENTITY a "bad">]><x>&a;</x>',
        "<bad",
        "<OperationStateResponse><Result><Code>1</Code></Result></OperationStateResponse>",
    ],
)
def test_malformed_or_unauthenticated_xml_cannot_complete_payment(
    configuration: Configuration,
    response: str,
) -> None:
    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda _: httpx.Response(
                    200,
                    text=response,
                ),
            ),
        ) as client:
            provider = RobokassaPaymentProvider(
                client,
                Variables(
                    environment="production",
                    robokassa_merchant_login="shop",
                    robokassa_password1="first",
                    robokassa_password2="second",
                ),
                configuration.server.billing.provider,
            )
            with pytest.raises(
                BillingPaymentError,
            ):
                await provider.payment(
                    "123",
                )

    asyncio.run(
        run(),
    )


def test_production_create_is_disabled_without_launch_gate(
    configuration: Configuration,
) -> None:
    async def run() -> None:
        def respond(
            _: httpx.Request,
        ) -> httpx.Response:
            pytest.fail(
                "Real payment creation must be blocked before network I/O",
            )

        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
        ) as client:
            provider = RobokassaPaymentProvider(
                client,
                Variables(
                    environment="production",
                    robokassa_merchant_login="shop",
                    robokassa_password1="first",
                    robokassa_password2="second",
                ),
                configuration.server.billing.provider,
            )
            with pytest.raises(
                BillingUnavailableError,
            ):
                await provider.create(
                    "order",
                    {},
                )

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "url",
    [
        "http://auth.robokassa.ru/merchant/Invoice/test",
        "https://evil.example/merchant/Invoice/test",
        "https://auth.robokassa.ru.evil.example/merchant/Invoice/test",
    ],
)
def test_invoice_redirect_is_restricted_to_payment_origin(
    url: str,
) -> None:
    with pytest.raises(
        BillingPaymentError,
    ):
        RobokassaPaymentProvider._checkout_url(
            url,
        )


def test_invoice_recovery_uses_documented_nested_response(
    configuration: Configuration,
) -> None:
    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda _: httpx.Response(
                    200,
                    json={
                        "isSuccess": True,
                        "invoiceInformation": {
                            "invId": 123,
                            "invoiceStatus": "NotPaid",
                            "payments": [],
                            "invoicePaymentUrl": "https://auth.robokassa.ru/merchant/Invoice/recovered",
                        },
                    },
                ),
            ),
        ) as client:
            provider = RobokassaPaymentProvider(
                client,
                Variables(
                    environment="development",
                    robokassa_merchant_login="shop",
                    robokassa_password1="first",
                    robokassa_password2="second",
                ),
                configuration.server.billing.provider,
            )
            assert (
                await provider.invoice(
                    "123",
                )
                == "https://auth.robokassa.ru/merchant/Invoice/recovered"
            )

    asyncio.run(
        run(),
    )
