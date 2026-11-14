from __future__ import annotations

import asyncio
import base64
import hashlib
import hmac
import json
import re
from decimal import Decimal, localcontext
from typing import Any
from urllib.parse import urlsplit
from xml.etree import ElementTree

import httpx

from app.core.configuration.variables import Variables
from app.error.billing_payment_error import BillingPaymentError
from app.error.billing_payment_rejected_error import BillingPaymentRejectedError
from app.error.billing_purchase_error import BillingPurchaseError
from app.error.billing_unavailable_error import BillingUnavailableError
from app.model.http_client_config import HttpClientConfig

_MAX_AMOUNT: Decimal = Decimal(
    "21474836.47",
)  # Minor units fit the ledger's PostgreSQL INTEGER.


class RobokassaPaymentProvider:
    """Server-only transport. Acceptance of a request never proves payment."""

    def __init__(
        self,
        client: httpx.AsyncClient,
        variables: Variables,
        configuration: HttpClientConfig,
    ) -> None:
        self._client = client
        self._settings = variables
        self._configuration = configuration

    @property
    def is_available(
        self,
    ) -> bool:
        return bool(
            self._settings.robokassa_merchant_login
            and self._settings.robokassa_password1
            and self._settings.robokassa_password2,
        )

    def verify_notification(
        self,
        fields: dict[str, str],
    ) -> None:
        if not self.is_available:
            raise BillingUnavailableError()
        invoice = fields.get(
            "InvId",
            "",
        )
        if (
            not re.fullmatch(
                r"[1-9][0-9]{0,18}",
                invoice,
            )
            or int(
                invoice,
            )
            > 2**63 - 1
        ):
            raise BillingPurchaseError()
        amount = fields.get(
            "OutSum",
            "",
        )
        extra = [
            f"{key}={fields[key]}"
            for key in sorted(
                fields,
            )
            if key.startswith(
                "Shp_",
            )
        ]
        signature = self._hash(
            ":".join(
                [amount, invoice, self._settings.robokassa_password2 or "", *extra],
            ),
        )
        received = fields.get(
            "SignatureValue",
            "",
        )
        if not re.fullmatch(
            r"[0-9A-Fa-f]+",
            received,
        ) or not hmac.compare_digest(
            signature.lower(),
            received.lower(),
        ):
            raise BillingPurchaseError()
        self.money_minor(
            amount,
        )

    async def create(
        self,
        order_id: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        if not self.is_available or (
            not self._settings.is_robokassa_test and not self._settings.is_robokassa_live_enabled
        ):
            raise BillingUnavailableError()
        invoice = payload["invoice_id"]
        amount = payload["amount"]["value"]
        if payload.get(
            "payment_method_id",
        ):
            fields = {
                "MerchantLogin": self._settings.robokassa_merchant_login or "",
                "InvoiceID": invoice,
                "PreviousInvoiceID": payload["payment_method_id"],
                "OutSum": amount,
                "Description": payload["description"],
                "Shp_order_id": order_id,
            }
            if payload.get(
                "email",
            ):
                fields["Email"] = payload["email"]
            fields["SignatureValue"] = self._hash(
                f"{fields['MerchantLogin']}:{amount}:{invoice}:{self._settings.robokassa_password1}:Shp_order_id={order_id}",
            )
            if self._settings.is_robokassa_test:
                fields["IsTest"] = "1"
            raw = await self._request(
                "POST",
                "https://auth.robokassa.ru/Merchant/Recurring",
                data=fields,
            )
            if not re.fullmatch(
                rb"OK(?:[0-9]+)?",
                raw.strip(),
            ):
                raise BillingPaymentError()
            return self._pending(
                invoice,
            )
        additional: dict[str, str] = {}
        if payload.get(
            "is_auto_renewing",
            True,
        ):
            additional["Recurring"] = "true"
        if payload.get(
            "email",
        ):
            additional["Email"] = payload["email"]
        if self._settings.is_robokassa_test:
            additional["IsTest"] = "1"
        result = await self._invoice(
            "CreateInvoice",
            {
                "MerchantLogin": self._settings.robokassa_merchant_login,
                "InvoiceType": "OneTime",
                "InvId": int(
                    invoice,
                ),
                "OutSum": amount,
                "Description": payload["description"],
                "ExpirationDate": payload["expires_at"],
                "Aliases": ["BankCard"],
                "UserFields": {"Shp_order_id": order_id},
                "InvoiceItems": [
                    {
                        "Name": payload["description"],
                        "Quantity": 1,
                        "Cost": float(
                            Decimal(
                                amount,
                            ),
                        ),
                        "Tax": "none",
                        "PaymentMethod": "full_payment",
                        "PaymentObject": "service",
                    }
                ],
                "AdditionalParameters": additional,
            },
        )
        if (
            result.get(
                "isSuccess",
            )
            is not True
        ):
            if (
                result.get(
                    "isSuccess",
                )
                is False
            ):
                raise BillingPaymentRejectedError()
            raise BillingPaymentError()
        if str(
            result.get(
                "invId",
            ),
        ) != invoice or not isinstance(
            result.get(
                "id",
            ),
            str,
        ):
            raise BillingPaymentError()
        return {
            **self._pending(
                invoice,
            ),
            "invoice_uuid": result["id"],
            "confirmation": {
                "confirmation_url": self._checkout_url(
                    result.get(
                        "url",
                    ),
                )
            },
        }

    async def payment(
        self,
        invoice_id: str,
    ) -> dict[str, Any]:
        if self._settings.is_robokassa_test:
            # OpStateExt does not support test operations. Only signed ResultURL completes them.
            return self._pending(
                invoice_id,
            )
        raw = await self._request(
            "POST",
            "https://auth.robokassa.ru/Merchant/WebService/Service.asmx/OpStateExt",
            data={
                "MerchantLogin": self._settings.robokassa_merchant_login or "",
                "InvoiceID": invoice_id,
                "Signature": self._hash(
                    f"{self._settings.robokassa_merchant_login}:{invoice_id}:{self._settings.robokassa_password2}",
                ),
            },
        )
        if b"<!DOCTYPE" in raw.upper() or b"<!ENTITY" in raw.upper():
            raise BillingPaymentError()
        try:
            root = ElementTree.fromstring(
                raw,
            )
        except ElementTree.ParseError as error:
            raise BillingPaymentError() from error
        for element in root.iter():
            element.tag = element.tag.rsplit(
                "}",
                1,
            )[-1]
        code = root.findtext(
            "Result/Code",
        )
        if code == "3":
            return self._pending(
                invoice_id,
            )
        if code != "0":
            raise BillingPaymentError()
        state = root.findtext(
            "State/Code",
        )
        if state not in {"10", "60", "100"}:
            return self._pending(
                invoice_id,
            )
        if state in {"10", "60"}:
            return {
                **self._pending(
                    invoice_id,
                ),
                "status": "canceled",
            }
        if root.findtext(
            "Info/OutCurrLabel",
        ) not in {"RUB", "RUR"}:
            raise BillingPaymentError()
        amount = (
            root.findtext(
                "Info/OutSum",
            )
            or ""
        )
        self.money_minor(
            amount,
        )
        op_key = root.findtext(
            "Info/OpKey",
        )
        if state == "100" and not op_key:
            raise BillingPaymentError()
        return {
            **self._pending(
                invoice_id,
            ),
            "status": "succeeded" if state == "100" else "canceled",
            "paid": state == "100",
            "amount": {"value": amount, "currency": "RUB"},
            "op_key": op_key,
        }

    async def invoice_information(
        self,
        invoice_id: str,
    ) -> dict[str, Any] | None:
        result = await self._invoice(
            "GetInvoiceInformation",
            {
                "MerchantLogin": self._settings.robokassa_merchant_login,
                "InvId": int(
                    invoice_id,
                ),
                **({"AdditionalParameters": {"IsTest": "1"}} if self._settings.is_robokassa_test else {}),
            },
        )
        if (
            result.get(
                "isSuccess",
            )
            is not True
        ):
            return None
        info = result.get(
            "invoiceInformation",
        )
        if (
            not isinstance(
                info,
                dict,
            )
            or str(
                info.get(
                    "invId",
                ),
            )
            != invoice_id
        ):
            raise BillingPaymentError()
        if info.get(
            "invoiceStatus",
        ) not in ("NotPaid", "Paid", "Expired") or not isinstance(
            info.get(
                "payments",
            ),
            list,
        ):
            raise BillingPaymentError()
        return info

    async def invoice(
        self,
        invoice_id: str,
    ) -> str | None:
        info = await self.invoice_information(
            invoice_id,
        )
        if info is None or info["invoiceStatus"] == "Expired":
            return None
        return self._checkout_url(
            info.get(
                "invoicePaymentUrl",
            ),
        )

    async def deactivate_invoice(
        self,
        invoice_id: str,
    ) -> None:
        result = await self._invoice(
            "DeactivateInvoice",
            {
                "MerchantLogin": self._settings.robokassa_merchant_login,
                "InvId": int(
                    invoice_id,
                ),
                **({"AdditionalParameters": {"IsTest": "1"}} if self._settings.is_robokassa_test else {}),
            },
        )
        if (
            result.get(
                "isSuccess",
            )
            is not True
        ):
            raise BillingPaymentError()

    async def refund(
        self,
        op_key: str,
        amount: str,
        operation_id: str,
    ) -> str:
        # Caller persists operation_id BEFORE this non-idempotent call. Never replay it.
        del operation_id
        if self._settings.is_robokassa_test or not self._settings.robokassa_password3:
            raise BillingUnavailableError()
        raw = await self._request(
            "POST",
            "https://services.robokassa.ru/RefundService/Refund/Create",
            json_body=self._jwt(
                {
                    "OpKey": op_key,
                    "RefundSum": float(
                        Decimal(
                            amount,
                        ),
                    ),
                },
                self._settings.robokassa_password3,
                "sha256",
                "HS256",
            ),
        )
        result = self._json(
            raw,
        )
        if result.get(
            "success",
        ) is not True or not isinstance(
            result.get(
                "requestId",
            ),
            str,
        ):
            raise BillingPaymentError()
        return str(
            result["requestId"],
        )

    async def refund_state(
        self,
        request_id: str,
    ) -> dict[str, Any]:
        raw = await self._request(
            "GET",
            "https://services.robokassa.ru/RefundService/Refund/GetState",
            params={"id": request_id},
        )
        result = self._json(
            raw,
        )
        if result.get(
            "requestId",
        ) != request_id or result.get(
            "label",
        ) not in {"finished", "processing", "canceled"}:
            raise BillingPaymentError()
        self.money_minor(
            result.get(
                "amount",
            ),
        )
        return result

    def _pending(
        self,
        invoice_id: str,
    ) -> dict[str, Any]:
        return {
            "id": invoice_id,
            "status": "pending",
            "paid": False,
            "test": self._settings.is_robokassa_test,
            "recipient": {"account_id": self._settings.robokassa_merchant_login},
            "payment_method": {"id": invoice_id, "saved": True, "type": "bank_card"},
        }

    async def _invoice(
        self,
        method: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        raw = await self._request(
            "POST",
            "https://services.robokassa.ru/InvoiceServiceWebApi/api/" + method,
            json_body=self._jwt(
                payload,
                f"{self._settings.robokassa_merchant_login}:{self._settings.robokassa_password1}",
                self._settings.robokassa_hash_algorithm,
                self._settings.robokassa_hash_algorithm.upper(),
            ),
        )
        return self._json(
            raw,
        )

    async def _request(
        self,
        method: str,
        url: str,
        *,
        data: dict[str, str] | None = None,
        params: dict[str, str] | None = None,
        json_body: str | None = None,
    ) -> bytes:
        if not self.is_available:
            raise BillingUnavailableError()
        try:
            async with (
                asyncio.timeout(
                    self._configuration.operation_timeout_seconds,
                ),
                self._client.stream(
                    method,
                    url,
                    data=data,
                    params=params,
                    json=json_body,
                    timeout=self._configuration.timeout(),
                    follow_redirects=False,
                ) as response,
            ):
                if response.status_code != 200:
                    raise BillingPaymentError()
                result = bytearray()
                async for chunk in response.aiter_bytes():
                    result.extend(
                        chunk,
                    )
                    if (
                        len(
                            result,
                        )
                        > self._configuration.max_response_bytes
                    ):
                        raise BillingPaymentError()
                return bytes(
                    result,
                )
        except (httpx.HTTPError, TimeoutError) as error:
            raise BillingPaymentError() from error

    def _hash(
        self,
        value: str,
    ) -> str:
        return hashlib.new(
            self._settings.robokassa_hash_algorithm,
            value.encode(),
        ).hexdigest()

    @staticmethod
    def _jwt(
        payload: dict[str, Any],
        secret: str,
        algorithm: str,
        label: str,
    ) -> str:
        def encode(
            value: Any,
        ) -> str:
            return (
                base64.urlsafe_b64encode(
                    json.dumps(
                        value,
                        ensure_ascii=False,
                        separators=(",", ":"),
                    ).encode(),
                )
                .decode()
                .rstrip(
                    "=",
                )
            )

        body = (
            encode(
                {"typ": "JWT", "alg": label},
            )
            + "."
            + encode(
                payload,
            )
        )
        signature = (
            base64.urlsafe_b64encode(
                hmac.new(
                    secret.encode(),
                    body.encode(),
                    algorithm,
                ).digest(),
            )
            .decode()
            .rstrip(
                "=",
            )
        )
        return body + "." + signature

    @staticmethod
    def _json(
        raw: bytes,
    ) -> dict[str, Any]:
        try:
            result = json.loads(
                raw,
            )
        except (ValueError, UnicodeDecodeError) as error:
            raise BillingPaymentError() from error
        if not isinstance(
            result,
            dict,
        ):
            raise BillingPaymentError()
        return result

    @staticmethod
    def _checkout_url(
        value: Any,
    ) -> str:
        if not isinstance(
            value,
            str,
        ):
            raise BillingPaymentError()
        url = urlsplit(
            value,
        )
        if (
            url.scheme != "https"
            or url.netloc.lower() != "auth.robokassa.ru"
            or not url.path.lower().startswith(
                "/merchant/invoice/",
            )
            or url.fragment
        ):
            raise BillingPaymentError()
        return value

    @staticmethod
    def money_minor(
        value: Any,
    ) -> int:
        text = str(
            value,
        )
        if (
            len(
                text,
            )
            > 64
        ):
            raise BillingPurchaseError()
        try:
            amount = Decimal(
                text,
            )
            if (
                not amount.is_finite()
                or amount < 0
                or amount > _MAX_AMOUNT
                or 0
                < amount
                < Decimal(
                    "0.01",
                )
            ):
                raise BillingPurchaseError()
            with localcontext() as context:
                context.prec = (
                    len(
                        text,
                    )
                    + 2
                )
                minor = amount * 100
                if minor != minor.to_integral_value():
                    raise BillingPurchaseError()
                return int(
                    minor,
                )
        except (ValueError, ArithmeticError) as error:
            raise BillingPurchaseError() from error
