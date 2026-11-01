from __future__ import annotations

import asyncio
import logging

import httpx

from app.core.application.service_factory import ServiceFactory
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.configuration.variables import Variables
from app.database.billing_database import BillingDatabase
from app.error.billing_unavailable_error import BillingUnavailableError

logger = logging.getLogger(
    __name__,
)


class BillingWorker:
    def __init__(
        self,
        variables: Variables,
    ) -> None:
        self._variables = variables

    async def run(
        self,
    ) -> None:
        if not self._variables.billing_database_url:
            raise BillingUnavailableError()
        configuration = ConfigurationLoader(
            self._variables.configuration_directory,
        ).load()
        async with httpx.AsyncClient(
            timeout=configuration.server.billing.provider.timeout(),
        ) as client:
            database = BillingDatabase(
                self._variables.billing_database_url,
            )
            try:
                await database.check()
                service = ServiceFactory(
                    client,
                    configuration,
                    self._variables,
                ).create_subscriptions(
                    database,
                )
                while True:
                    try:
                        await service.tick()
                    except Exception as error:
                        logger.error(
                            "Billing reconciliation failed: cause=%s",
                            type(
                                error,
                            ).__name__,
                        )
                    await asyncio.sleep(
                        configuration.server.billing.reconciliation_interval_seconds,
                    )
            finally:
                await database.close()
