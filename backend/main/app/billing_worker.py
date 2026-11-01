from __future__ import annotations

import asyncio

from app.core.configuration.variables import Variables
from app.core.logging.logging_configurator import LoggingConfigurator
from app.service.billing.billing_worker import BillingWorker

if __name__ == "__main__":
    variables = Variables()
    LoggingConfigurator.configure(
        variables,
    )
    asyncio.run(
        BillingWorker(
            variables,
        ).run(),
    )
