from __future__ import annotations

import asyncio

from app.core.configuration.variables import Variables
from app.core.logging.logging_configurator import LoggingConfigurator
from app.service.report.report_generation_worker import ReportGenerationWorker

if __name__ == "__main__":
    variables = Variables()
    LoggingConfigurator.configure(
        variables,
    )
    asyncio.run(
        ReportGenerationWorker(
            variables,
        ).run(),
    )
