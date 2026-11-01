from __future__ import annotations

import asyncio
from concurrent.futures import Future
from threading import Event, Lock
from typing import Any

import httpx
from yookassa.client import ApiClient
from yookassa.domain.common import UserAgent

from app.model.http_client_config import HttpClientConfig


class YooKassaSDKClient(ApiClient):  # type: ignore[misc]  # The official SDK has no typing metadata.
    """Per-call SDK client with isolated credentials and a bounded async transport.

    ApiClient's default initializer requires global Configuration credentials.
    Its request/header/error methods only need the public fields initialized here;
    execute replaces its synchronous requests transport and raw-payload logging.
    """

    def __init__(
        self,
        client: httpx.AsyncClient,
        shop_id: str,
        secret: str,
        configuration: HttpClientConfig,
        loop: asyncio.AbstractEventLoop,
        deadline: float,
    ) -> None:
        self.shop_id = shop_id
        self.shop_password = secret
        self.auth_token = None
        self.user_agent = UserAgent()
        self.endpoint = "https://api.yookassa.ru/v3"
        self.transport_error: Exception | None = None
        self._client = client
        self._configuration = configuration
        self._loop = loop
        self._deadline = deadline
        self._is_cancelled = Event()
        self._lock = Lock()
        self._future: Future[httpx.Response] | None = None

    def execute(
        self,
        body: dict[str, Any] | None,
        method: str,
        path: str,
        query_params: dict[str, Any] | None,
        request_headers: dict[str, str],
    ) -> httpx.Response:
        try:
            with self._lock:
                if self._is_cancelled.is_set() or self._loop.time() >= self._deadline:
                    raise TimeoutError(
                        "YooKassa request is no longer active",
                    )
                self._future = asyncio.run_coroutine_threadsafe(
                    self._send(
                        method,
                        path,
                        body,
                        query_params,
                        request_headers,
                    ),
                    self._loop,
                )
                future = self._future
            return future.result(
                timeout=max(
                    0,
                    self._deadline - self._loop.time(),
                ),
            )
        except Exception as error:
            # SDK 3.13.0 assumes every transport exception has .response. Retain
            # the original cause even if its error handler masks a timeout/cancel.
            self.transport_error = error
            self.cancel()
            raise

    def cancel(
        self,
    ) -> None:
        with self._lock:
            self._is_cancelled.set()
            if self._future is not None:
                self._future.cancel()

    async def _send(
        self,
        method: str,
        path: str,
        body: dict[str, Any] | None,
        query_params: dict[str, Any] | None,
        headers: dict[str, str],
    ) -> httpx.Response:
        if self._is_cancelled.is_set() or self._loop.time() >= self._deadline:
            raise TimeoutError(
                "YooKassa request is no longer active",
            )
        async with asyncio.timeout_at(
            self._deadline,
        ):
            return await self._client.request(
                method,
                self.endpoint + path,
                params=query_params,
                headers=headers,
                json=body,
                timeout=self._configuration.timeout(),
                follow_redirects=False,
            )
