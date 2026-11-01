from __future__ import annotations

import asyncio
from typing import Any

import httpx
from yookassa.domain.common import RequestObject
from yookassa.domain.exceptions import BadRequestError
from yookassa.domain.request import PaymentRequest, RefundRequest

from app.error.billing_payment_error import BillingPaymentError
from app.error.billing_payment_rejected_error import BillingPaymentRejectedError
from app.model.http_client_config import HttpClientConfig
from app.service.billing.yookassa_sdk_client import YooKassaSDKClient


class YooKassaSDKAdapter:
    # Python 3.11's default executor has at least five workers. Leave capacity
    # for async HTTP DNS resolution and App Check while SDK calls wait for I/O.
    _MAX_CONCURRENT_CALLS = 4

    def __init__(
        self,
        client: httpx.AsyncClient,
        shop_id: str,
        secret: str,
        configuration: HttpClientConfig,
    ) -> None:
        self._client = client
        self._shop_id = shop_id
        self._secret = secret
        self._configuration = configuration
        self._slots = asyncio.Semaphore(
            self._MAX_CONCURRENT_CALLS,
        )

    async def request(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
        operation_id: str | None = None,
        query_params: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        loop = asyncio.get_running_loop()
        deadline = loop.time() + self._configuration.operation_timeout_seconds
        sdk = YooKassaSDKClient(
            self._client,
            self._shop_id,
            self._secret,
            self._configuration,
            loop,
            deadline,
        )
        try:
            async with asyncio.timeout_at(
                deadline,
            ):
                async with self._slots:
                    data = await asyncio.to_thread(
                        self._request,
                        sdk,
                        method,
                        path,
                        payload,
                        operation_id,
                        query_params,
                    )
            if not isinstance(
                data,
                dict,
            ):
                raise ValueError(
                    "Unexpected provider response",
                )
            return data
        except asyncio.CancelledError:
            sdk.cancel()
            raise
        except Exception as error:
            sdk.cancel()
            if (
                method == "POST"
                and path == "/payments"
                and isinstance(
                    error,
                    BadRequestError,
                )
            ):
                raise BillingPaymentRejectedError() from error
            raise BillingPaymentError() from (sdk.transport_error or error)

    @staticmethod
    def _request(
        sdk: YooKassaSDKClient,
        method: str,
        path: str,
        payload: dict[str, Any] | None,
        operation_id: str | None,
        query_params: dict[str, str] | None,
    ) -> Any:
        body: RequestObject | None = None
        if method == "POST":
            if not operation_id or payload is None:
                raise ValueError(
                    "Mutating SDK requests require a persisted operation ID and payload",
                )
            if path == "/payments":
                body = PaymentRequest(
                    payload,
                )
            elif path == "/refunds":
                body = RefundRequest(
                    payload,
                )
            else:
                raise ValueError(
                    "Unsupported SDK operation",
                )
        elif method != "GET" or (
            path != "/me"
            and path != "/refunds"
            and not path.startswith(
                "/payments/",
            )
        ):
            raise ValueError(
                "Unsupported SDK operation",
            )
        return sdk.request(
            method=method,
            path=path,
            headers={"Idempotence-Key": operation_id} if operation_id else {},
            query_params=query_params,
            body=body,
        )
