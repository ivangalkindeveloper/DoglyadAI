from __future__ import annotations

import asyncio
from unittest.mock import AsyncMock, Mock, patch

import httpx
import pytest

from app.core.app_check.app_check import AppCheck
from app.core.application.service_factory import ServiceFactory
from app.core.configuration.variables import Variables
from app.database.billing_database import BillingDatabase
from app.error.billing_unavailable_error import BillingUnavailableError
from app.service.billing import billing_worker
from app.service.billing.billing_worker import BillingWorker
from app.service.neural_model.neural_model_service_factory import NeuralModelServiceFactory


def test_worker_requires_database_before_creating_resources() -> None:
    async def run() -> None:
        variables = Variables(
            environment="development",
            billing_database_url=None,
        )
        with patch.object(
            billing_worker.httpx,
            "AsyncClient",
        ) as make_client:
            with pytest.raises(
                BillingUnavailableError,
            ):
                await BillingWorker(
                    variables,
                ).run()
            make_client.assert_not_called()

    asyncio.run(
        run(),
    )


def test_worker_retries_safely_and_cancellation_closes_resources(
    caplog: pytest.LogCaptureFixture,
) -> None:
    async def run() -> None:
        # No Firebase credentials or GPU route map: neither is needed by this process.
        variables = Variables(
            environment="development",
            billing_database_url="postgresql+asyncpg://unused",
            firebase_credentials_path=None,
            inference_endpoints_path=None,
        )
        database = Mock(
            spec=BillingDatabase,
        )
        database.check = AsyncMock()
        database.close = AsyncMock()
        service = Mock()
        service.tick = AsyncMock(
            side_effect=[
                RuntimeError(
                    "secret-provider-response",
                ),
                asyncio.CancelledError(),
            ],
        )
        client = httpx.AsyncClient()
        with (
            patch.object(
                billing_worker.httpx,
                "AsyncClient",
                return_value=client,
            ),
            patch.object(
                billing_worker,
                "BillingDatabase",
                return_value=database,
            ),
            patch.object(
                ServiceFactory,
                "create_subscriptions",
                return_value=service,
            ),
            patch.object(
                NeuralModelServiceFactory,
                "create",
            ) as create_model,
            patch.object(
                AppCheck,
                "initialize",
            ) as initialize_app_check,
            patch.object(
                billing_worker.asyncio,
                "sleep",
                new_callable=AsyncMock,
            ) as sleep,
            pytest.raises(
                asyncio.CancelledError,
            ),
        ):
            await BillingWorker(
                variables,
            ).run()
        assert client.is_closed
        database.check.assert_awaited_once()
        database.close.assert_awaited_once()
        create_model.assert_not_called()
        initialize_app_check.assert_not_called()
        assert service.tick.await_count == 2
        sleep.assert_awaited_once_with(
            30,
        )
        assert "cause=RuntimeError" in caplog.text
        assert "secret-provider-response" not in caplog.text

    asyncio.run(
        run(),
    )


def test_failed_worker_startup_closes_database_and_http_client() -> None:
    async def run() -> None:
        variables = Variables(
            environment="development",
            billing_database_url="postgresql+asyncpg://unused",
        )
        database = Mock(
            spec=BillingDatabase,
        )
        database.check = AsyncMock(
            side_effect=RuntimeError(
                "database unavailable",
            ),
        )
        database.close = AsyncMock()
        client = httpx.AsyncClient()
        with (
            patch.object(
                billing_worker.httpx,
                "AsyncClient",
                return_value=client,
            ),
            patch.object(
                billing_worker,
                "BillingDatabase",
                return_value=database,
            ),
            patch.object(
                ServiceFactory,
                "create_subscriptions",
            ) as create_service,
            pytest.raises(
                RuntimeError,
                match="database unavailable",
            ),
        ):
            await BillingWorker(
                variables,
            ).run()
        assert client.is_closed
        database.close.assert_awaited_once()
        create_service.assert_not_called()

    asyncio.run(
        run(),
    )
