"""Run the real report worker with a controlled local model boundary."""

import asyncio
from pathlib import Path

from app.core.configuration.variables import Variables
from app.core.logging.logging_configurator import LoggingConfigurator
from app.service.report.report_generation_worker import ReportGenerationWorker
from regression_model_control import ControlledModelService


class RegressionWorker(ReportGenerationWorker):
    async def execute(self, job, store, reports, model_service, subscriptions, timeout):
        number = ""
        if job.payload:
            payload = store.cipher.open(job.payload)
            number = payload.get("examination", {}).get("examinationData", {}).get("examinationNumber", "")
        await super().execute(
            job, store, reports,
            ControlledModelService(model_service, Path("/regression-evidence/worker"), number, str(job.id)),
            subscriptions, timeout,
        )


if __name__ == "__main__":
    variables = Variables()
    if variables.environment != "development" or variables.model_service_type.value != "mock":
        raise RuntimeError("Regression worker requires development configuration and the local mock model")
    LoggingConfigurator.configure(variables)
    asyncio.run(RegressionWorker(variables).run())
