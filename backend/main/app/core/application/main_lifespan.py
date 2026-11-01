from __future__ import annotations

from contextlib import AbstractAsyncContextManager
from types import TracebackType

import httpx
from fastapi import FastAPI

from app.core.app_check.app_check import AppCheck
from app.core.application.service_factory import ServiceFactory
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.configuration.variables import Variables
from app.database.billing_database import BillingDatabase


class MainLifespan(AbstractAsyncContextManager[None]):
    def __init__(
        self,
        app: FastAPI,
    ) -> None:
        self._app = app
        self._http_client = httpx.AsyncClient(
            timeout=app.state.server_config.inference.timeout(),
        )
        self._billing_database: BillingDatabase | None = None

    async def __aenter__(
        self,
    ) -> None:
        try:
            variables: Variables = self._app.state.variables
            configuration = ConfigurationLoader(
                variables.configuration_directory,
            ).load(
                self._app.state.server_config,
            )
            AppCheck.initialize(
                variables,
            )
            factory = ServiceFactory(
                self._http_client,
                configuration,
                variables,
            )
            subscriptions = None
            if variables.billing_database_url:
                self._billing_database = BillingDatabase(
                    variables.billing_database_url,
                )
                await self._billing_database.check()
                subscriptions = factory.create_subscriptions(
                    self._billing_database,
                )
            self._app.state.container = factory.create_main_container(
                subscriptions,
            )
        except BaseException:
            try:
                if self._billing_database is not None:
                    await self._billing_database.close()
            finally:
                await self._http_client.aclose()
            raise

    async def __aexit__(
        self,
        exc_type: type[BaseException] | None,
        exc_value: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        try:
            if self._billing_database is not None:
                await self._billing_database.close()
        finally:
            await self._http_client.aclose()
