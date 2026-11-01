from __future__ import annotations

import asyncio
import base64
import json
from threading import Event
from typing import Any, Literal
from unittest.mock import patch
from uuid import uuid4

import httpx
import pytest
from yookassa import Configuration as SDKConfiguration
from yookassa.domain.exceptions import ApiError

from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.error.billing_payment_error import BillingPaymentError
from app.error.billing_unavailable_error import BillingUnavailableError
from app.service.billing.yookassa_payment_provider import YooKassaPaymentProvider
from app.service.billing.yookassa_sdk_adapter import YooKassaSDKAdapter
from app.service.billing.yookassa_sdk_client import YooKassaSDKClient


@pytest.mark.parametrize(
    "environment,is_live_enabled,is_provider_test,is_allowed",
    [
        ("development", False, True, True),
        ("development", True, True, True),
        ("development", False, False, False),
        ("development", True, False, False),
        ("production", False, True, False),
        ("production", True, True, False),
        ("production", False, False, False),
        ("production", True, False, True),
        ("development", False, None, False),
        ("development", False, 1, False),
        ("production", True, None, False),
        ("production", True, 0, False),
    ],
)
def test_environment_restricts_merchant_mode_before_charging(
    configuration: Configuration,
    environment: Literal["development", "production"],
    is_live_enabled: bool,
    is_provider_test: object,
    is_allowed: bool,
) -> None:
    async def run() -> None:
        writes: list[httpx.Request] = []

        def respond(
            request: httpx.Request,
        ) -> httpx.Response:
            if request.url.path == "/v3/me":
                return httpx.Response(
                    200,
                    json={"account_id": "test", "status": "enabled", "test": is_provider_test},
                )
            writes.append(
                request,
            )
            return httpx.Response(
                200,
                json={"id": "test-payment"},
            )

        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
        ) as client:
            provider = YooKassaPaymentProvider(
                client,
                Variables(
                    environment=environment,
                    yookassa_shop_id="test",
                    yookassa_secret_key="test-secret",
                    is_yookassa_live_enabled=is_live_enabled,
                ),
                configuration.server.billing.provider,
            )
            payload = {
                "amount": {"value": "100.00", "currency": "RUB"},
                "payment_token": "test-token",
            }
            if is_allowed:
                await provider.create(
                    "persisted-operation",
                    payload,
                )
                assert (
                    len(
                        writes,
                    )
                    == 1
                )
            else:
                with pytest.raises(
                    BillingUnavailableError,
                ):
                    await provider.create(
                        "persisted-operation",
                        payload,
                    )
                assert not writes

    asyncio.run(
        run(),
    )


def test_refund_pagination_keeps_payment_filter_and_cursor(
    configuration: Configuration,
) -> None:
    async def run() -> None:
        payment_id = str(
            uuid4(),
        )
        requests: list[httpx.Request] = []

        def respond(
            request: httpx.Request,
        ) -> httpx.Response:
            requests.append(
                request,
            )
            assert request.url.path == "/v3/refunds"
            assert request.url.params["payment_id"] == payment_id
            assert request.url.params["limit"] == "100"
            assert "Idempotence-Key" not in request.headers
            if "cursor" not in request.url.params:
                return httpx.Response(
                    200,
                    json={"items": [{"id": "first"}], "next_cursor": "next-page"},
                )
            assert request.url.params["cursor"] == "next-page"
            return httpx.Response(
                200,
                json={"items": [{"id": "second"}]},
            )

        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
        ) as client:
            provider = YooKassaPaymentProvider(
                client,
                Variables(
                    environment="development",
                    yookassa_shop_id="test",
                    yookassa_secret_key="test-secret",
                ),
                configuration.server.billing.provider,
            )
            assert await provider.refunds(
                payment_id,
            ) == [{"id": "first"}, {"id": "second"}]
        assert (
            len(
                requests,
            )
            == 2
        )

    asyncio.run(
        run(),
    )


def test_repeated_refund_cursor_fails_instead_of_looping(
    configuration: Configuration,
) -> None:
    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda _: httpx.Response(
                    200,
                    json={"items": [], "next_cursor": "repeated"},
                ),
            ),
        ) as client:
            provider = YooKassaPaymentProvider(
                client,
                Variables(
                    environment="development",
                    yookassa_shop_id="test",
                    yookassa_secret_key="test-secret",
                ),
                configuration.server.billing.provider,
            )
            with pytest.raises(
                BillingPaymentError,
            ):
                await provider.refunds(
                    str(
                        uuid4(),
                    ),
                )

    asyncio.run(
        run(),
    )


def test_refund_pagination_has_one_deadline_across_pages(
    configuration: Configuration,
) -> None:
    async def run() -> None:
        count = 0

        async def respond(
            _: httpx.Request,
        ) -> httpx.Response:
            nonlocal count
            count += 1
            await asyncio.sleep(
                0.03,
            )
            return httpx.Response(
                200,
                json={
                    "items": [],
                    "next_cursor": str(
                        count,
                    ),
                },
            )

        config = configuration.server.billing.provider.model_copy(
            update={"operation_timeout_seconds": 0.08},
        )
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
        ) as client:
            provider = YooKassaPaymentProvider(
                client,
                Variables(
                    environment="development",
                    yookassa_shop_id="test",
                    yookassa_secret_key="test-secret",
                ),
                config,
            )
            with pytest.raises(
                BillingPaymentError,
            ):
                await asyncio.wait_for(
                    provider.refunds(
                        str(
                            uuid4(),
                        ),
                    ),
                    1,
                )
        assert 1 <= count <= 4

    asyncio.run(
        run(),
    )


def test_sdk_keeps_per_merchant_auth_payload_and_idempotency_isolated(
    configuration: Configuration,
) -> None:
    async def run() -> None:
        requests: list[httpx.Request] = []
        global_credentials = (SDKConfiguration.account_id, SDKConfiguration.secret_key, SDKConfiguration.auth_token)

        async def respond(
            request: httpx.Request,
        ) -> httpx.Response:
            requests.append(
                request,
            )
            credentials = base64.b64decode(
                request.headers["Authorization"].split()[1],
            ).decode()
            shop, secret = credentials.split(
                ":",
            )
            assert secret == "secret-" + shop
            if request.url.path == "/v3/me":
                return httpx.Response(
                    200,
                    json={"account_id": shop, "test": True, "status": "enabled"},
                )
            return httpx.Response(
                200,
                json={
                    "merchant": shop,
                    "payload": json.loads(
                        request.content,
                    ),
                },
            )

        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
        ) as client:
            first = YooKassaPaymentProvider(
                client,
                Variables(
                    environment="development",
                    yookassa_shop_id="first",
                    yookassa_secret_key="secret-first",
                ),
                configuration.server.billing.provider,
            )
            second = YooKassaPaymentProvider(
                client,
                Variables(
                    environment="development",
                    yookassa_shop_id="second",
                    yookassa_secret_key="secret-second",
                ),
                configuration.server.billing.provider,
            )
            payload = {
                "amount": {"value": "100.01", "currency": "RUB"},
                "capture": True,
                "payment_token": "test-token",
                "metadata": {"order_id": "original-order"},
            }
            first_result, second_result = await asyncio.gather(
                first.create(
                    "first-operation",
                    payload,
                ),
                second.create(
                    "second-operation",
                    payload,
                ),
            )
            assert first_result["merchant"] == "first" and second_result["merchant"] == "second"
            for result in (first_result, second_result):
                assert result["payload"]["amount"] == payload["amount"]
                assert result["payload"]["payment_token"] == "test-token"
                assert result["payload"]["metadata"] == payload["metadata"]
            writes = [request for request in requests if request.method == "POST"]
            assert {request.headers["Idempotence-Key"] for request in writes} == {"first-operation", "second-operation"}
            assert all(
                ("YM-User-Agent" in request.headers for request in requests),
            )
            payment_id = str(
                uuid4(),
            )
            refund = await first.refund(
                payment_id,
                "10.25",
                "persisted-refund-operation",
            )
            assert refund["payload"]["payment_id"] == payment_id
            assert refund["payload"]["amount"] == {"value": "10.25", "currency": "RUB"}
            assert requests[-1].headers["Idempotence-Key"] == "persisted-refund-operation"
        assert (
            SDKConfiguration.account_id,
            SDKConfiguration.secret_key,
            SDKConfiguration.auth_token,
        ) == global_credentials

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "status",
    [400, 401, 403, 404, 429, 500],
)
def test_sdk_errors_are_wrapped_without_losing_the_sdk_cause(
    configuration: Configuration,
    status: int,
) -> None:
    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda _: httpx.Response(
                    status,
                    json={
                        "type": "error",
                        "id": str(
                            uuid4(),
                        ),
                        "code": "invalid_request",
                        "description": "test",
                    },
                ),
            ),
        ) as client:
            adapter = YooKassaSDKAdapter(
                client,
                "test",
                "test-secret",
                configuration.server.billing.provider,
            )
            with pytest.raises(
                BillingPaymentError,
            ) as error:
                await adapter.request(
                    "GET",
                    "/me",
                )
            assert isinstance(
                error.value.__cause__,
                ApiError,
            )

    asyncio.run(
        run(),
    )


def test_sdk_transport_failure_preserves_original_http_error(
    configuration: Configuration,
) -> None:
    async def run() -> None:
        def respond(
            request: httpx.Request,
        ) -> httpx.Response:
            raise httpx.ConnectError(
                "test connection failure",
                request=request,
            )

        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
        ) as client:
            adapter = YooKassaSDKAdapter(
                client,
                "test",
                "test-secret",
                configuration.server.billing.provider,
            )
            with pytest.raises(
                BillingPaymentError,
            ) as error:
                await adapter.request(
                    "GET",
                    "/me",
                )
            assert isinstance(
                error.value.__cause__,
                httpx.ConnectError,
            )

    asyncio.run(
        run(),
    )


def test_operation_deadline_cancels_inflight_async_transport(
    configuration: Configuration,
) -> None:
    async def run() -> None:
        stopped = asyncio.Event()

        async def respond(
            _: httpx.Request,
        ) -> httpx.Response:
            try:
                await asyncio.Event().wait()
                raise AssertionError(
                    "Unreachable",
                )
            finally:
                stopped.set()

        config = configuration.server.billing.provider.model_copy(
            update={"operation_timeout_seconds": 0.05},
        )
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
        ) as client:
            adapter = YooKassaSDKAdapter(
                client,
                "test",
                "test-secret",
                config,
            )
            with pytest.raises(
                BillingPaymentError,
            ):
                await adapter.request(
                    "GET",
                    "/me",
                )
            await asyncio.wait_for(
                stopped.wait(),
                timeout=1,
            )

    asyncio.run(
        run(),
    )


def test_cancelled_queued_sdk_call_cannot_start_a_late_request(
    configuration: Configuration,
) -> None:
    async def run() -> None:
        started, release, finished = Event(), Event(), Event()
        requests: list[httpx.Request] = []
        original = YooKassaSDKClient.request

        def delayed(
            sdk: YooKassaSDKClient,
            *args: Any,
            **kwargs: Any,
        ) -> Any:
            started.set()
            try:
                assert release.wait(
                    timeout=2,
                )
                return original(
                    sdk,
                    *args,
                    **kwargs,
                )
            finally:
                finished.set()

        def respond(
            request: httpx.Request,
        ) -> httpx.Response:
            requests.append(
                request,
            )
            return httpx.Response(
                200,
                json={},
            )

        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
        ) as client:
            adapter = YooKassaSDKAdapter(
                client,
                "test",
                "test-secret",
                configuration.server.billing.provider,
            )
            with patch.object(
                YooKassaSDKClient,
                "request",
                delayed,
            ):
                task = asyncio.create_task(
                    adapter.request(
                        "GET",
                        "/me",
                    ),
                )
                try:
                    assert await asyncio.to_thread(
                        started.wait,
                        1,
                    )
                    task.cancel()
                    with pytest.raises(
                        asyncio.CancelledError,
                    ):
                        await task
                finally:
                    release.set()
                    assert await asyncio.to_thread(
                        finished.wait,
                        1,
                    )
            assert requests == []

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "path",
    ["/payments", "/refunds"],
)
def test_sdk_never_generates_a_replacement_operation_id(
    configuration: Configuration,
    path: str,
) -> None:
    async def run() -> None:
        requests: list[httpx.Request] = []

        def respond(
            request: httpx.Request,
        ) -> httpx.Response:
            requests.append(
                request,
            )
            return httpx.Response(
                200,
                json={},
            )

        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
        ) as client:
            adapter = YooKassaSDKAdapter(
                client,
                "test",
                "test-secret",
                configuration.server.billing.provider,
            )
            with pytest.raises(
                BillingPaymentError,
            ):
                await adapter.request(
                    "POST",
                    path,
                    {"amount": {"value": "1.00", "currency": "RUB"}},
                )
            assert requests == []

    asyncio.run(
        run(),
    )


def test_sdk_validates_payment_model_before_network_io(
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
            return httpx.Response(
                200,
                json={},
            )

        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
        ) as client:
            adapter = YooKassaSDKAdapter(
                client,
                "test",
                "test-secret",
                configuration.server.billing.provider,
            )
            with pytest.raises(
                BillingPaymentError,
            ):
                await adapter.request(
                    "POST",
                    "/payments",
                    {
                        "amount": {"value": "1.00", "currency": "RUB"},
                        "payment_token": "token",
                        "payment_method_id": "mutually-exclusive-saved-method",
                    },
                    "persisted-order-id",
                )
            assert requests == []

    asyncio.run(
        run(),
    )


def test_sdk_does_not_follow_redirects_or_log_tokens(
    configuration: Configuration,
    caplog: pytest.LogCaptureFixture,
) -> None:
    async def run() -> None:
        requests: list[httpx.Request] = []

        def respond(
            request: httpx.Request,
        ) -> httpx.Response:
            requests.append(
                request,
            )
            return httpx.Response(
                302,
                headers={"Location": "https://other.example"},
                json={"type": "error"},
            )

        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
            follow_redirects=True,
        ) as client:
            adapter = YooKassaSDKAdapter(
                client,
                "test",
                "test-secret",
                configuration.server.billing.provider,
            )
            with pytest.raises(
                BillingPaymentError,
            ):
                await adapter.request(
                    "POST",
                    "/payments",
                    {
                        "amount": {"value": "1.00", "currency": "RUB"},
                        "payment_token": "sensitive-test-token",
                    },
                    "persisted-order-id",
                )
            assert (
                len(
                    requests,
                )
                == 1
                and requests[0].url.host == "api.yookassa.ru"
            )
            assert "sensitive-test-token" not in caplog.text and "test-secret" not in caplog.text

    asyncio.run(
        run(),
    )


def test_parallel_sdk_calls_leave_executor_capacity_for_other_work(
    configuration: Configuration,
) -> None:
    async def run() -> None:
        active = 0
        maximum = 0

        async def respond(
            _: httpx.Request,
        ) -> httpx.Response:
            nonlocal active, maximum
            active += 1
            maximum = max(
                maximum,
                active,
            )
            try:
                await asyncio.sleep(
                    0.01,
                )
                return httpx.Response(
                    200,
                    json={"account_id": "test"},
                )
            finally:
                active -= 1

        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                respond,
            ),
        ) as client:
            adapter = YooKassaSDKAdapter(
                client,
                "test",
                "test-secret",
                configuration.server.billing.provider,
            )
            responses = await asyncio.gather(
                *(
                    adapter.request(
                        "GET",
                        "/me",
                    )
                    for _ in range(
                        20,
                    )
                ),
            )
            assert len(
                responses,
            ) == 20 and all(
                (value["account_id"] == "test" for value in responses),
            )
            assert maximum <= 4
            assert active == 0

    asyncio.run(
        run(),
    )
