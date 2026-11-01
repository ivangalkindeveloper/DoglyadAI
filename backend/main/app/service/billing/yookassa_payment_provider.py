from __future__ import annotations

import asyncio
from typing import Any

import httpx

from app.core.configuration.variables import Variables
from app.error.billing_payment_error import BillingPaymentError
from app.error.billing_payment_rejected_error import BillingPaymentRejectedError
from app.error.billing_unavailable_error import BillingUnavailableError
from app.model.http_client_config import HttpClientConfig
from app.service.billing.yookassa_sdk_adapter import YooKassaSDKAdapter


class YooKassaPaymentProvider:
    def __init__(
        self,
        client: httpx.AsyncClient,
        variables: Variables,
        configuration: HttpClientConfig,
    ) -> None:
        self._shop_id = variables.yookassa_shop_id
        self._secret = variables.yookassa_secret_key
        self._is_test = variables.is_yookassa_test
        self._is_live_enabled = variables.is_yookassa_live_enabled
        self._operation_timeout_seconds = configuration.operation_timeout_seconds
        self._sdk = YooKassaSDKAdapter(
            client,
            self._shop_id or "",
            self._secret or "",
            configuration,
        )

    @property
    def is_available(
        self,
    ) -> bool:
        return bool(
            self._shop_id and self._secret,
        )

    async def create(
        self,
        order_id: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        # Check the merchant BEFORE charging, not only the response after money moved.
        try:
            merchant = await self._request(
                "GET",
                "/me",
            )
        except BillingPaymentError as error:
            # Payment creation was not attempted when merchant verification failed.
            raise BillingPaymentRejectedError() from error
        if (
            str(
                merchant.get(
                    "account_id",
                ),
            )
            != self._shop_id
            or merchant.get(
                "status",
            )
            != "enabled"
        ):
            raise BillingUnavailableError()
        if (
            merchant.get(
                "test",
            )
            is not self._is_test
        ):
            raise BillingUnavailableError()
        if not self._is_test and not self._is_live_enabled:
            raise BillingUnavailableError()
        return await self._request(
            "POST",
            "/payments",
            payload,
            order_id,
        )

    async def payment(
        self,
        payment_id: str,
    ) -> dict[str, Any]:
        return await self._request(
            "GET",
            f"/payments/{payment_id}",
        )

    async def refund(
        self,
        payment_id: str,
        amount: str,
        operation_id: str,
    ) -> dict[str, Any]:
        return await self._request(
            "POST",
            "/refunds",
            {"payment_id": payment_id, "amount": {"value": amount, "currency": "RUB"}},
            operation_id,
        )

    async def refunds(
        self,
        payment_id: str,
    ) -> list[dict[str, Any]]:
        try:
            async with asyncio.timeout(
                self._operation_timeout_seconds,
            ):
                return await self._refund_pages(
                    payment_id,
                )
        except TimeoutError as error:
            raise BillingPaymentError() from error

    async def _refund_pages(
        self,
        payment_id: str,
    ) -> list[dict[str, Any]]:
        items: list[dict[str, Any]] = []
        query = {"payment_id": payment_id, "limit": "100"}
        seen_cursors: set[str] = set()
        while True:
            page = await self._request(
                "GET",
                "/refunds",
                query_params=query,
            )
            values = page.get(
                "items",
            )
            if not isinstance(
                values,
                list,
            ) or any(
                (
                    not isinstance(
                        item,
                        dict,
                    )
                    for item in values
                ),
            ):
                raise BillingPaymentError()
            items.extend(
                values,
            )
            cursor = page.get(
                "next_cursor",
            )
            if cursor is None:
                return items
            if (
                not isinstance(
                    cursor,
                    str,
                )
                or not cursor
                or cursor in seen_cursors
            ):
                raise BillingPaymentError()
            seen_cursors.add(
                cursor,
            )
            query["cursor"] = cursor

    async def _request(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
        operation_id: str | None = None,
        query_params: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        if not self._shop_id or not self._secret:
            raise BillingUnavailableError()
        return await self._sdk.request(
            method,
            path,
            payload,
            operation_id,
            query_params,
        )
