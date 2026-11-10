from __future__ import annotations

import asyncio
import json
import os
from collections.abc import AsyncGenerator
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import httpx
import pytest
from cryptography.fernet import Fernet
from fastapi import FastAPI
from sqlalchemy import select

from app.core.app_check.app_check import AppCheck
from app.core.application.service_dependencies import ServiceDependencies
from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.core.localization.language_code import LanguageCode
from app.core.logging.request_id_log_filter import RequestIdLogFilter, current_request_id
from app.database.billing_subscription_db import BillingSubscriptionDB
from app.database.billing_usage_db import BillingUsageDB
from app.database.report_generation_db import ReportGenerationDB
from app.error.inference_unavailable_error import InferenceUnavailableError
from app.error.invalid_report_response_error import InvalidReportResponseError
from app.error.report_generation_conflict_error import ReportGenerationConflictError
from app.error.report_generation_not_found_error import ReportGenerationNotFoundError
from app.model.neural_model.neural_model_service_request import NeuralModelServiceRequest
from app.model.ultrasound.us_examination_model_report_response import USExaminationModelReportResponse
from app.model.ultrasound.us_report_generation_config import USReportGenerationConfig
from app.model.ultrasound.us_report_generation_request import USReportGenerationRequest
from app.model.ultrasound.us_report_preview_response import USReportPreviewResponse
from app.service.billing.subscription_service import SubscriptionService
from app.service.report.report_generation_cipher import ReportGenerationCipher
from app.service.report.report_generation_jobs import ReportGenerationJobs
from app.service.report.report_generation_service import ReportGenerationService
from app.service.report.report_generation_store import ReportGenerationStore
from app.service.report.report_generation_worker import ReportGenerationWorker
from tests.support.billing.billing_test_context import BillingTestContext
from tests.support.report_streaming.controlled_report_model import ControlledReportModel


@pytest.fixture(
    params=[
        (
            "The supplied description does not state the left thyroid lobe size. "
            "Please specify the left thyroid lobe size. "
        )
        * 3,
        " ".join(
            (
                "Необходима консультация уролога для исключения урологических заболеваний. "
                f"Separate finding number {index}."
                for index in range(
                    3,
                )
            ),
        ),
        (
            "Также необходимо уточнить, является ли конкремент 4 мм, обнаруженный в мочевом пузыре, "
            "единственным конкрементом, или есть другие конкременты. "
        )
        * 3,
    ],
)
def repeating_report_text(
    request: pytest.FixtureRequest,
) -> str:
    return str(
        request.param,
    )


def test_complete_rejects_repetition_even_without_intermediate_previews(
    configuration: Configuration,
    request_body: USReportGenerationRequest,
    repeating_report_text: str,
) -> None:
    service = ReportGenerationService(
        configuration,
        ControlledReportModel(),
    )
    text = json.dumps(
        {
            "description": "Synthetic description.",
            "conclusion": "Synthetic conclusion.",
            "descriptionRemarks": repeating_report_text,
        },
    )
    with pytest.raises(
        InvalidReportResponseError,
    ):
        service.complete(
            text,
            request_body.examination,
            model_id="google/medgemma-4b-it",
            language_code=LanguageCode.EN,
        )


def test_repetition_stops_upstream_and_preserves_incomplete_snapshot_without_charging(
    tmp_path: Path,
    configuration: Configuration,
    request_body: USReportGenerationRequest,
    monkeypatch: pytest.MonkeyPatch,
    repeating_report_text: str,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            async with ctx.database.session() as session, session.begin():
                session.add(
                    BillingSubscriptionDB(
                        id=str(
                            uuid4(),
                        ),
                        owner_id=owner,
                        source="yookassa",
                        external_id="repetition-test",
                        plan_id="monthly",
                        entitlement="pro",
                        paid_until=datetime.now(
                            UTC,
                        )
                        + timedelta(
                            days=1,
                        ),
                        updated_at=datetime.now(
                            UTC,
                        ),
                    ),
                )
            ctx.service.require_report = AsyncMock()
            closed = asyncio.Event()

            async def stream(
                request: NeuralModelServiceRequest,
            ) -> AsyncGenerator[str, None]:
                try:
                    yield (
                        '{"description":"Synthetic description.",'
                        '"conclusion":"Synthetic conclusion.","descriptionRemarks":"'
                    )
                    await asyncio.sleep(
                        0.01,
                    )
                    yield repeating_report_text
                    pytest.fail(
                        "The worker must stop consuming a repeating generation",
                    )
                finally:
                    closed.set()

            model = ControlledReportModel()
            monkeypatch.setattr(
                model,
                "stream",
                stream,
            )
            reports = ReportGenerationService(
                configuration,
                model,
            )
            store = ReportGenerationStore(
                ctx.database,
                ReportGenerationCipher(
                    Fernet.generate_key().decode(),
                ),
                USReportGenerationConfig(
                    preview_interval_seconds=0.001,
                    poll_interval_seconds=0.01,
                ),
            )
            jobs = ReportGenerationJobs(
                store,
                reports,
                ctx.service,
            )
            await jobs.start(
                owner,
                request_body,
                language=LanguageCode.EN,
                app_check_token="test-token",
                request_id="d" * 32,
            )
            job = await store.claim(
                130,
            )
            assert job is not None
            await ReportGenerationWorker(
                Variables(
                    model_service_type="mock",
                ),
            ).execute(
                job,
                store,
                reports,
                model,
                ctx.service,
                10,
            )
            result = await store.get(
                owner,
                job.id,
            )
            assert closed.is_set()
            assert result.status.value == "failed"
            assert result.errorCode == "invalidReportResponse"
            assert result.report is None
            assert result.partialReport.description == "Synthetic description."
            assert result.partialReport.descriptionRemarks is None
            async with ctx.database.session() as session:
                usage = await session.get(
                    BillingUsageDB,
                    job.id,
                )
                assert usage is not None and usage.status == "failed"

    asyncio.run(
        run(),
    )


@pytest.fixture(
    autouse=True,
)
def isolated_job_connections(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # In-memory SQLite shares one connection and cannot model concurrent worker/read transactions.
    if not os.environ.get(
        "DOGLYAD_TEST_POSTGRES_URL",
    ):
        monkeypatch.setenv(
            "DOGLYAD_TEST_POSTGRES_URL",
            f"sqlite+aiosqlite:///{tmp_path}/report-jobs.sqlite",
        )


@pytest.fixture
def request_body() -> USReportGenerationRequest:
    return USReportGenerationRequest.model_validate(
        {
            "requestId": str(
                uuid4(),
            ),
            "examination": {
                "settingsAI": {"selectedNeuralModelId": "google/medgemma-4b-it"},
                "examinationData": {
                    "usExaminationTypeId": "bladder",
                    "photos": [],
                    "examinationNumber": "STREAM-1",
                    "patientName": "Synthetic Patient",
                    "patientGender": "female",
                    "patientDateOfBirth": "1991-01-01T00:00:00Z",
                    "examinationDescription": "Synthetic examination.",
                    "isPatientPreparedForExamination": True,
                    "isPatientConsent": True,
                },
                "isRecommendationsIncluded": False,
            },
        },
    )


def test_idempotency_owner_isolation_encryption_and_snapshot_recovery(
    tmp_path: Path,
    configuration: Configuration,
    request_body: USReportGenerationRequest,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            async with ctx.database.session() as session, session.begin():
                session.add(
                    BillingSubscriptionDB(
                        id=str(
                            uuid4(),
                        ),
                        owner_id=owner,
                        source="yookassa",
                        external_id="stream-test",
                        plan_id="monthly",
                        entitlement="pro",
                        paid_until=datetime.now(
                            UTC,
                        )
                        + timedelta(
                            days=1,
                        ),
                        updated_at=datetime.now(
                            UTC,
                        ),
                    ),
                )

            outsider = str(
                (await ctx.service.register()).ownerId,
            )
            store = ReportGenerationStore(
                ctx.database,
                ReportGenerationCipher(
                    Fernet.generate_key().decode(),
                ),
                USReportGenerationConfig(),
            )
            first = await store.create(
                owner,
                request_body,
                {"patient": "Synthetic Patient", "appCheckToken": "private-test-token"},
                "google/medgemma-4b-it",
            )
            duplicate = await store.create(
                owner,
                request_body,
                {},
                "google/medgemma-4b-it",
            )
            assert first == duplicate
            with pytest.raises(
                ReportGenerationNotFoundError,
            ):
                await store.get(
                    outsider,
                    str(
                        first.generationId,
                    ),
                )
            with pytest.raises(
                ReportGenerationNotFoundError,
            ):
                await store.cancel(
                    outsider,
                    str(
                        first.generationId,
                    ),
                )
            altered = request_body.model_copy(
                deep=True,
            )
            altered.examination.examinationData.patientName = "Changed"
            with pytest.raises(
                ReportGenerationConflictError,
            ):
                await store.create(
                    owner,
                    altered,
                    {},
                    "google/medgemma-4b-it",
                )
            job = await store.claim(
                130,
            )
            assert job is not None and job.payload is not None
            assert job.expires_at - job.created_at == timedelta(
                hours=12,
            )
            assert b"Synthetic Patient" not in job.payload and b"private-test-token" not in job.payload
            assert (
                await store.claim(
                    130,
                )
                is None
            )
            await ctx.service.reserve(
                owner,
                job.id,
            )
            await store.preview(
                job.id,
                USReportPreviewResponse(
                    description="Partial synthetic text",
                ),
            )
            assert (
                await store.get(
                    owner,
                    job.id,
                )
            ).partialReport.description == "Partial synthetic text"
            final = USExaminationModelReportResponse(
                date=datetime.now(
                    UTC,
                ),
                modelId=job.model_id,
                description="Synthetic description",
                conclusion="Synthetic conclusion",
            )
            await store.finish(
                job.id,
                report=final,
            )
            await store.finish(
                job.id,
                error_code="lateFailure",
            )
            complete = await store.get(
                owner,
                job.id,
            )
            assert complete.status.value == "completed" and complete.report == final
            async with ctx.database.session() as session:
                persisted = await session.get(
                    ReportGenerationDB,
                    job.id,
                )
                usage = await session.get(
                    BillingUsageDB,
                    job.id,
                )
                assert persisted is not None and persisted.payload is None
                assert b"Synthetic description" not in persisted.snapshot
                assert usage is not None and usage.status == "completed"
            async with ctx.database.session() as session, session.begin():
                persisted = await session.get(
                    ReportGenerationDB,
                    job.id,
                )
                assert persisted is not None
                persisted.expires_at = datetime.now(
                    UTC,
                ) - timedelta(
                    seconds=1,
                )
            with pytest.raises(
                ReportGenerationNotFoundError,
            ):
                await store.get(
                    owner,
                    job.id,
                )
            await store.clean()
            async with ctx.database.session() as session:
                assert (
                    await session.get(
                        ReportGenerationDB,
                        job.id,
                    )
                    is None
                )

    asyncio.run(
        run(),
    )


def test_cancel_and_deadline_release_usage_and_keep_partial(
    tmp_path: Path,
    configuration: Configuration,
    request_body: USReportGenerationRequest,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            async with ctx.database.session() as session, session.begin():
                session.add(
                    BillingSubscriptionDB(
                        id=str(
                            uuid4(),
                        ),
                        owner_id=owner,
                        source="yookassa",
                        external_id="stream-test",
                        plan_id="monthly",
                        entitlement="pro",
                        paid_until=datetime.now(
                            UTC,
                        )
                        + timedelta(
                            days=1,
                        ),
                        updated_at=datetime.now(
                            UTC,
                        ),
                    ),
                )

            store = ReportGenerationStore(
                ctx.database,
                ReportGenerationCipher(
                    Fernet.generate_key().decode(),
                ),
                USReportGenerationConfig(),
            )
            await store.create(
                owner,
                request_body,
                {},
                "google/medgemma-4b-it",
            )
            job = await store.claim(
                130,
            )
            assert job is not None
            await ctx.service.reserve(
                owner,
                job.id,
            )
            await store.preview(
                job.id,
                USReportPreviewResponse(
                    description="Unfinished",
                ),
            )
            async with ctx.database.session() as session, session.begin():
                persisted = await session.get(
                    ReportGenerationDB,
                    job.id,
                )
                assert persisted is not None
                persisted.deadline_at = datetime.now(
                    UTC,
                ) - timedelta(
                    seconds=1,
                )
            result = await store.get(
                owner,
                job.id,
            )
            assert result.status.value == "failed" and result.errorCode == "generationTimeout"
            assert result.partialReport.description == "Unfinished"
            async with ctx.database.session() as session:
                usage = await session.get(
                    BillingUsageDB,
                    job.id,
                )
                assert usage is not None and usage.status == "failed"
            request_body.requestId = uuid4()
            queued = await store.create(
                owner,
                request_body,
                {},
                "google/medgemma-4b-it",
            )
            cancelled = await store.cancel(
                owner,
                str(
                    queued.generationId,
                ),
            )
            assert cancelled.status.value == "cancelled"
            assert (
                await store.claim(
                    130,
                )
                is None
            )

    asyncio.run(
        run(),
    )


def test_worker_continues_after_subscriber_disconnect_and_reserves_once(
    tmp_path: Path,
    configuration: Configuration,
    request_body: USReportGenerationRequest,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            async with ctx.database.session() as session, session.begin():
                session.add(
                    BillingSubscriptionDB(
                        id=str(
                            uuid4(),
                        ),
                        owner_id=owner,
                        source="yookassa",
                        external_id="stream-test",
                        plan_id="monthly",
                        entitlement="pro",
                        paid_until=datetime.now(
                            UTC,
                        )
                        + timedelta(
                            days=1,
                        ),
                        updated_at=datetime.now(
                            UTC,
                        ),
                    ),
                )

            # Subscription access is tested separately; this test uses synthetic generation.
            ctx.service.require_report = AsyncMock()
            model = ControlledReportModel()
            reports = ReportGenerationService(
                configuration,
                model,
            )
            store = ReportGenerationStore(
                ctx.database,
                ReportGenerationCipher(
                    Fernet.generate_key().decode(),
                ),
                USReportGenerationConfig(
                    preview_interval_seconds=0.001,
                    poll_interval_seconds=0.01,
                ),
            )
            jobs = ReportGenerationJobs(
                store,
                reports,
                ctx.service,
            )
            started = await jobs.start(
                owner,
                request_body,
                language=LanguageCode.EN,
                app_check_token="test-token",
                request_id="a" * 32,
            )
            job = await store.claim(
                130,
            )
            assert job is not None
            worker = ReportGenerationWorker(
                Variables(
                    model_service_type="mock",
                ),
            )
            running = asyncio.create_task(
                worker.execute(
                    job,
                    store,
                    reports,
                    model,
                    ctx.service,
                    10,
                ),
            )
            await asyncio.wait_for(
                model.first.wait(),
                2,
            )
            stream = jobs.events(
                owner,
                str(
                    started.generationId,
                ),
            )
            first = await anext(
                stream,
            )
            assert "reportDelta" in first
            await stream.aclose()
            assert not running.done()
            model.proceed.set()
            await asyncio.wait_for(
                running,
                2,
            )
            restored = await store.get(
                owner,
                job.id,
            )
            assert restored.status.value == "completed" and restored.report is not None
            assert model.calls == 1
            duplicate = await jobs.start(
                owner,
                request_body,
                language=LanguageCode.EN,
                app_check_token="new-test-token",
                request_id="b" * 32,
            )
            assert duplicate.report == restored.report
            async with ctx.database.session() as session:
                usages = list(
                    await session.scalars(
                        select(
                            BillingUsageDB,
                        ),
                    ),
                )
                assert (
                    len(
                        usages,
                    )
                    == 1
                    and usages[0].status == "completed"
                )

    asyncio.run(
        run(),
    )


def test_partial_json_retains_decoded_text_without_requiring_final_schema() -> None:
    partial = USReportPreviewResponse.parse_partial(
        '{"description":"Текст \\u0430", "conclusion":"Начало',
    )
    assert partial.description == "Текст \u0430"
    assert partial.conclusion == "Начало"
    assert (
        USReportPreviewResponse.parse_partial(
            "[",
        ).description
        is None
    )


def test_http_jobs_require_app_check_and_owner_and_use_dynamic_policies(
    tmp_path: Path,
    configuration: Configuration,
    request_body: USReportGenerationRequest,
    app: FastAPI,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = await ctx.service.register()
            outsider = await ctx.service.register()
            ctx.service.require_report = AsyncMock()
            store = ReportGenerationStore(
                ctx.database,
                ReportGenerationCipher(
                    Fernet.generate_key().decode(),
                ),
                USReportGenerationConfig(),
            )
            jobs = ReportGenerationJobs(
                store,
                ReportGenerationService(
                    configuration,
                    ControlledReportModel(),
                ),
                ctx.service,
            )
            app.dependency_overrides[ServiceDependencies.subscriptions] = lambda: ctx.service
            app.dependency_overrides[ServiceDependencies.report_jobs] = lambda: jobs
            path = "/v1/ultrasound/report_generations"
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(
                    app=app,
                ),
                base_url="http://test",
            ) as client:
                missing = await client.post(
                    path,
                    json=request_body.model_dump(
                        mode="json",
                    ),
                )
                assert missing.status_code == 401
                app.dependency_overrides[AppCheck.verify] = lambda: None
                missing_owner = await client.post(
                    path,
                    json=request_body.model_dump(
                        mode="json",
                    ),
                )
                assert missing_owner.status_code == 401
                headers = {"Authorization": "Bearer " + owner.accessToken, "X-Firebase-AppCheck": "synthetic-token"}
                first = await client.post(
                    path,
                    json=request_body.model_dump(
                        mode="json",
                    ),
                    headers=headers,
                )
                assert first.status_code == 202
                specific = path + "/" + first.json()["generationId"]
                assert (
                    await client.get(
                        specific,
                        headers=headers,
                    )
                ).status_code == 200
                denied = await client.get(
                    specific,
                    headers={"Authorization": "Bearer " + outsider.accessToken},
                )
                assert denied.status_code == 404
                cancellation = await client.post(
                    specific + "/cancel",
                    headers=headers,
                )
                assert cancellation.json()["status"] == "cancelled"
                recovered = await client.get(
                    specific + "/events",
                    headers=headers,
                )
                assert recovered.status_code == 200
                assert "text/event-stream" in recovered.headers["content-type"]
                assert '"status":"cancelled"' in recovered.text

    asyncio.run(
        run(),
    )


def test_running_cancellation_stops_worker_and_refunds_reservation(
    tmp_path: Path,
    configuration: Configuration,
    request_body: USReportGenerationRequest,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            async with ctx.database.session() as session, session.begin():
                session.add(
                    BillingSubscriptionDB(
                        id=str(
                            uuid4(),
                        ),
                        owner_id=owner,
                        source="yookassa",
                        external_id="cancel-test",
                        plan_id="monthly",
                        entitlement="pro",
                        paid_until=datetime.now(
                            UTC,
                        )
                        + timedelta(
                            days=1,
                        ),
                        updated_at=datetime.now(
                            UTC,
                        ),
                    ),
                )
            ctx.service.require_report = AsyncMock()
            model = ControlledReportModel()
            reports = ReportGenerationService(
                configuration,
                model,
            )
            store = ReportGenerationStore(
                ctx.database,
                ReportGenerationCipher(
                    Fernet.generate_key().decode(),
                ),
                USReportGenerationConfig(
                    poll_interval_seconds=0.01,
                ),
            )
            jobs = ReportGenerationJobs(
                store,
                reports,
                ctx.service,
            )
            await jobs.start(
                owner,
                request_body,
                language=LanguageCode.EN,
                app_check_token="test-token",
                request_id="c" * 32,
            )
            job = await store.claim(
                130,
            )
            assert job is not None
            task = asyncio.create_task(
                ReportGenerationWorker(
                    Variables(
                        model_service_type="mock",
                    ),
                ).execute(
                    job,
                    store,
                    reports,
                    model,
                    ctx.service,
                    10,
                ),
            )
            await asyncio.wait_for(
                model.first.wait(),
                2,
            )
            await store.cancel(
                owner,
                job.id,
            )
            await asyncio.wait_for(
                task,
                2,
            )
            result = await store.get(
                owner,
                job.id,
            )
            assert result.status.value == "cancelled"
            assert result.report is None
            assert result.partialReport.description == "Synthetic "
            async with ctx.database.session() as session:
                usage = await session.get(
                    BillingUsageDB,
                    job.id,
                )
                assert usage is not None and usage.status == "failed"

    asyncio.run(
        run(),
    )


@pytest.mark.skipif(
    not os.environ.get(
        "DOGLYAD_TEST_POSTGRES_URL",
        "",
    ).startswith(
        "postgresql+",
    ),
    reason="Requires independent PostgreSQL transactions",
)
def test_postgres_serializes_duplicate_starts_and_claims(
    tmp_path: Path,
    configuration: Configuration,
    request_body: USReportGenerationRequest,
) -> None:
    async def run() -> None:
        async with BillingTestContext(
            tmp_path,
            configuration,
        ) as ctx:
            owner = str(
                (await ctx.service.register()).ownerId,
            )
            store = ReportGenerationStore(
                ctx.database,
                ReportGenerationCipher(
                    Fernet.generate_key().decode(),
                ),
                USReportGenerationConfig(),
            )
            responses = await asyncio.gather(
                *(
                    store.create(
                        owner,
                        request_body,
                        {},
                        "google/medgemma-4b-it",
                    )
                    for _ in range(
                        12,
                    )
                ),
            )
            assert (
                len(
                    {response.generationId for response in responses},
                )
                == 1
            )
            claims = await asyncio.gather(
                store.claim(
                    130,
                ),
                store.claim(
                    130,
                ),
            )
            assert (
                sum(
                    (job is not None for job in claims),
                )
                == 1
            )
            requests = [
                request_body.model_copy(
                    update={"requestId": uuid4()},
                )
                for _ in range(
                    3,
                )
            ]
            results = await asyncio.gather(
                *(
                    store.create(
                        owner,
                        request,
                        {},
                        "google/medgemma-4b-it",
                    )
                    for request in requests
                ),
                return_exceptions=True,
            )
            assert (
                sum(
                    (
                        isinstance(
                            result,
                            ReportGenerationConflictError,
                        )
                        for result in results
                    ),
                )
                == 2
            )

    asyncio.run(
        run(),
    )


def test_worker_logs_failure_code_and_request_id_without_private_payload(
    request_body: USReportGenerationRequest,
    caplog: pytest.LogCaptureFixture,
) -> None:
    async def run() -> None:
        request_id = "c" * 32
        private_text = "private patient data and App Check token"
        job = ReportGenerationDB(
            id=str(
                uuid4(),
            ),
            owner_id=str(
                uuid4(),
            ),
            model_id="test-model",
            payload=b"encrypted",
        )
        store = MagicMock(
            spec=ReportGenerationStore,
        )
        store.is_active.return_value = True
        store.cipher = MagicMock()
        store.cipher.open.return_value = {
            "requestId": request_id,
            "examination": request_body.examination.model_dump(
                mode="json",
            ),
            "language": "en",
            "appCheckToken": private_text,
        }
        subscriptions = MagicMock(
            spec=SubscriptionService,
        )
        error = InferenceUnavailableError()
        error.__cause__ = httpx.ConnectError(
            private_text,
        )
        subscriptions.require_report.side_effect = error
        log_filter = RequestIdLogFilter()
        caplog.handler.addFilter(
            log_filter,
        )
        token = current_request_id.set(
            "outer-context",
        )
        try:
            await ReportGenerationWorker(
                Variables(
                    model_service_type="mock",
                ),
            ).execute(
                job,
                store,
                MagicMock(
                    spec=ReportGenerationService,
                ),
                ControlledReportModel(),
                subscriptions,
                10,
            )
            assert current_request_id.get() == "outer-context"
        finally:
            current_request_id.reset(
                token,
            )
            caplog.handler.removeFilter(
                log_filter,
            )
        store.finish.assert_awaited_once_with(
            job.id,
            error_code="inferenceUnavailable",
        )
        record = next(
            (record for record in caplog.records if "Report generation failed" in record.message),
        )
        assert record.request_id == request_id
        assert "inferenceUnavailable" in record.message
        assert "ConnectError" in record.message
        assert job.id in record.message
        assert private_text not in caplog.text
        assert record.exc_info is None

    asyncio.run(
        run(),
    )
