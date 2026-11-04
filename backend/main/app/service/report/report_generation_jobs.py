from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator

from app.core.localization.language_code import LanguageCode
from app.model.ultrasound.us_report_generation_request import USReportGenerationRequest
from app.model.ultrasound.us_report_generation_response import USReportGenerationResponse
from app.service.billing.subscription_service import SubscriptionService
from app.service.report.report_generation_service import ReportGenerationService
from app.service.report.report_generation_store import ReportGenerationStore


class ReportGenerationJobs:
    def __init__(
        self,
        store: ReportGenerationStore,
        reports: ReportGenerationService,
        subscriptions: SubscriptionService,
    ) -> None:
        self.store = store
        self._reports = reports
        self._subscriptions = subscriptions

    async def start(
        self,
        owner_id: str,
        body: USReportGenerationRequest,
        *,
        language: LanguageCode,
        app_check_token: str | None,
        request_id: str,
    ) -> USReportGenerationResponse:
        prepared = self._reports.prepare(
            body.examination,
            language_code=language,
            app_check_token=app_check_token,
            request_id=request_id,
        )
        await self._subscriptions.require_report(
            owner_id,
            body.examination,
        )
        examination = body.examination.model_copy(
            update={
                "settingsAI": body.examination.settingsAI.model_copy(
                    update={"selectedNeuralModelId": prepared.model_id},
                )
            },
        )
        return await self.store.create(
            owner_id,
            body,
            {
                "examination": examination.model_dump(
                    mode="json",
                ),
                "language": language.value,
                "appCheckToken": app_check_token,
                "requestId": request_id,
            },
            prepared.model_id,
        )

    async def events(
        self,
        owner_id: str,
        generation_id: str,
    ) -> AsyncIterator[str]:
        # Every data event is an authoritative snapshot. Reconnects need no token replay.
        previous = -1
        last_sent = asyncio.get_running_loop().time()
        while True:
            result = await self.store.get(
                owner_id,
                generation_id,
            )
            if result.sequence != previous:
                event = (
                    "completed"
                    if result.report is not None
                    else "failed"
                    if result.status.is_terminal
                    else "reportDelta"
                )
                yield f"id: {result.sequence}\nevent: {event}\ndata: {result.model_dump_json()}\n\n"
                previous = result.sequence
                last_sent = asyncio.get_running_loop().time()
            if result.status.is_terminal:
                return
            if asyncio.get_running_loop().time() - last_sent >= self.store.config.heartbeat_seconds:
                yield "event: heartbeat\ndata: {}\n\n"
                last_sent = asyncio.get_running_loop().time()
            await asyncio.sleep(
                self.store.config.poll_interval_seconds,
            )
