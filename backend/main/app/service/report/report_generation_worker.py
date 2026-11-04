from __future__ import annotations

import asyncio
import logging
from contextlib import aclosing, suppress
from contextvars import Token

import httpx

from app.core.application.service_factory import ServiceFactory
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.configuration.variables import Variables
from app.core.localization.language_code import LanguageCode
from app.core.logging.request_id_log_filter import current_request_id
from app.database.billing_database import BillingDatabase
from app.database.report_generation_db import ReportGenerationDB
from app.error.api_error import ApiError
from app.error.report_generation_unavailable_error import ReportGenerationUnavailableError
from app.model.ultrasound.us_examination_model_report_response import USExaminationModelReportResponse
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.model.ultrasound.us_report_preview_response import USReportPreviewResponse
from app.service.billing.subscription_service import SubscriptionService
from app.service.neural_model.neural_model_service import NeuralModelService
from app.service.report.report_generation_service import ReportGenerationService
from app.service.report.report_generation_store import ReportGenerationStore

logger = logging.getLogger(
    __name__,
)


class ReportGenerationWorker:
    def __init__(
        self,
        variables: Variables,
    ) -> None:
        self._variables = variables

    async def run(
        self,
    ) -> None:
        if not self._variables.billing_database_url or not self._variables.report_generation_encryption_key:
            raise ReportGenerationUnavailableError()
        configuration = ConfigurationLoader(
            self._variables.configuration_directory,
        ).load()
        async with httpx.AsyncClient(
            timeout=configuration.server.inference.timeout(),
        ) as client:
            database = BillingDatabase(
                self._variables.billing_database_url,
            )
            tasks: set[asyncio.Task[None]] = set()
            try:
                factory = ServiceFactory(
                    client,
                    configuration,
                    self._variables,
                )
                subscriptions = factory.create_subscriptions(
                    database,
                )
                container = factory.create_main_container(
                    subscriptions,
                )
                if container.report_jobs is None:
                    raise ReportGenerationUnavailableError()
                store = container.report_jobs.store
                timeout = configuration.server.inference.operation_timeout_seconds
                while True:
                    for task in list(
                        tasks,
                    ):
                        if task.done():
                            tasks.remove(
                                task,
                            )
                            with suppress(
                                asyncio.CancelledError,
                            ):
                                error = task.exception()
                                if error is not None:
                                    logger.error(
                                        "Report worker task failed: cause=%s",
                                        type(
                                            error,
                                        ).__name__,
                                    )
                    await store.clean()
                    while (
                        len(
                            tasks,
                        )
                        < store.config.worker_concurrency
                    ):
                        job = await store.claim(
                            timeout,
                        )
                        if job is None:
                            break
                        tasks.add(
                            asyncio.create_task(
                                self.execute(
                                    job,
                                    store,
                                    container.report_generation,
                                    container.model_service,
                                    subscriptions,
                                    timeout,
                                ),
                            ),
                        )
                    await asyncio.sleep(
                        store.config.poll_interval_seconds,
                    )
            finally:
                for task in tasks:
                    task.cancel()
                await asyncio.gather(
                    *tasks,
                    return_exceptions=True,
                )
                await database.close()

    async def execute(
        self,
        job: ReportGenerationDB,
        store: ReportGenerationStore,
        reports: ReportGenerationService,
        model_service: NeuralModelService,
        subscriptions: SubscriptionService,
        timeout: float,
    ) -> None:
        generation: asyncio.Task[USExaminationModelReportResponse] | None = None
        cancellation: asyncio.Task[None] | None = None
        request_context: Token[str] | None = None
        try:
            if not job.payload or not await store.is_active(
                job.id,
            ):
                return
            payload = store.cipher.open(
                job.payload,
            )
            request_context = current_request_id.set(
                payload["requestId"],
            )
            body = USExaminationRequest.model_validate(
                payload["examination"],
            )
            language = LanguageCode(
                payload["language"],
            )
            await subscriptions.require_report(
                job.owner_id,
                body,
            )
            await subscriptions.reserve(
                job.owner_id,
                job.id,
            )
            if not await store.is_active(
                job.id,
            ):
                await subscriptions.finish_usage(
                    job.owner_id,
                    job.id,
                    is_success=False,
                )
                return
            prepared = reports.prepare(
                body,
                language_code=language,
                app_check_token=payload["appCheckToken"],
                request_id=payload["requestId"],
            )

            async def generate() -> USExaminationModelReportResponse:
                buffer = ""
                last_publish = 0.0
                previous = USReportPreviewResponse()
                async with aclosing(
                    model_service.stream(
                        prepared,
                    ),
                ) as source:
                    async for text in source:
                        buffer += text
                        if (
                            len(
                                buffer.encode(
                                    "utf-8",
                                ),
                            )
                            > store.config.max_response_bytes
                        ):
                            raise ValueError(
                                "Report exceeded configured limit",
                            )
                        now = asyncio.get_running_loop().time()
                        if now - last_publish >= store.config.preview_interval_seconds:
                            partial = reports.preview(
                                buffer,
                            )
                            if partial != previous:
                                await store.preview(
                                    job.id,
                                    partial,
                                )
                                previous = partial
                            last_publish = now
                return reports.complete(
                    buffer,
                    body,
                    model_id=prepared.model_id,
                    language_code=language,
                )

            async def monitor() -> None:
                while await store.is_active(
                    job.id,
                ):
                    await asyncio.sleep(
                        store.config.poll_interval_seconds,
                    )

            async with asyncio.timeout(
                timeout,
            ):
                generation = asyncio.create_task(
                    generate(),
                )
                cancellation = asyncio.create_task(
                    monitor(),
                )
                done, _ = await asyncio.wait(
                    [generation, cancellation],
                    return_when=asyncio.FIRST_COMPLETED,
                )
                if generation in done:
                    await store.finish(
                        job.id,
                        report=generation.result(),
                    )
                else:
                    cancellation.result()
                    generation.cancel()
                    with suppress(
                        asyncio.CancelledError,
                    ):
                        await generation
                    await subscriptions.finish_usage(
                        job.owner_id,
                        job.id,
                        is_success=False,
                    )
        except asyncio.CancelledError:
            await store.finish(
                job.id,
                error_code="generationInterrupted",
            )
            raise
        except ApiError as error:
            logger.warning(
                "Report generation failed: generation=%s model=%s code=%s cause=%s",
                job.id,
                job.model_id,
                error.code,
                type(
                    error.__cause__,
                ).__name__
                if error.__cause__ is not None
                else "-",
            )
            await store.finish(
                job.id,
                error_code=error.code,
            )
        except TimeoutError:
            logger.warning(
                "Report generation failed: generation=%s model=%s code=generationTimeout",
                job.id,
                job.model_id,
            )
            await store.finish(
                job.id,
                error_code="generationTimeout",
            )
        except Exception as error:
            logger.error(
                "Report generation failed: generation=%s model=%s cause=%s",
                job.id,
                job.model_id,
                type(
                    error,
                ).__name__,
            )
            await store.finish(
                job.id,
                error_code="reportGenerationFailed",
            )
        finally:
            if request_context is not None:
                current_request_id.reset(
                    request_context,
                )
            running = [task for task in (generation, cancellation) if task is not None]
            for task in running:
                if not task.done():
                    task.cancel()
            await asyncio.gather(
                *running,
                return_exceptions=True,
            )
