from __future__ import annotations

import hashlib
import json
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError

from app.database.billing_database import BillingDatabase
from app.database.billing_usage_db import BillingUsageDB
from app.database.report_generation_db import ReportGenerationDB
from app.error.report_generation_conflict_error import ReportGenerationConflictError
from app.error.report_generation_not_found_error import ReportGenerationNotFoundError
from app.model.ultrasound.us_examination_model_report_response import USExaminationModelReportResponse
from app.model.ultrasound.us_report_generation_config import USReportGenerationConfig
from app.model.ultrasound.us_report_generation_request import USReportGenerationRequest
from app.model.ultrasound.us_report_generation_response import USReportGenerationResponse
from app.model.ultrasound.us_report_generation_status import USReportGenerationStatus as Status
from app.model.ultrasound.us_report_preview_response import USReportPreviewResponse
from app.service.report.report_generation_cipher import ReportGenerationCipher


class ReportGenerationStore:
    def __init__(
        self,
        database: BillingDatabase,
        cipher: ReportGenerationCipher,
        config: USReportGenerationConfig,
    ) -> None:
        self.database = database
        self.cipher = cipher
        self.config = config

    async def create(
        self,
        owner_id: str,
        body: USReportGenerationRequest,
        payload: dict[str, Any],
        model_id: str,
    ) -> USReportGenerationResponse:
        digest = hashlib.sha256(
            json.dumps(
                body.model_dump(
                    mode="json",
                ),
                sort_keys=True,
            ).encode(),
        ).hexdigest()
        now = datetime.now(
            UTC,
        )
        try:
            async with self.database.session() as session, session.begin():
                await self.database.lock_owner(
                    session,
                    owner_id,
                )
                existing = await session.get(
                    ReportGenerationDB,
                    str(
                        body.requestId,
                    ),
                )
                if existing is not None:
                    if existing.owner_id != owner_id or existing.request_digest != digest:
                        raise ReportGenerationConflictError()
                    if (
                        existing.expires_at.replace(
                            tzinfo=UTC,
                        )
                        <= now
                    ):
                        raise ReportGenerationNotFoundError()
                    return self.response(
                        existing,
                    )
                if body.replacesGenerationId is not None:
                    previous = await session.get(
                        ReportGenerationDB,
                        str(
                            body.replacesGenerationId,
                        ),
                        with_for_update=True,
                    )
                    if previous is not None:
                        if previous.owner_id != owner_id:
                            raise ReportGenerationNotFoundError()
                        if not Status(
                            previous.status,
                        ).is_terminal:
                            self._terminate(
                                previous,
                                Status.CANCELLED,
                                "generationCancelled",
                            )
                            usage = await session.get(
                                BillingUsageDB,
                                previous.id,
                            )
                            if usage is not None and usage.status == "pending":
                                usage.status = "failed"
                pending = await session.scalar(
                    select(
                        func.count(),
                    )
                    .select_from(
                        ReportGenerationDB,
                    )
                    .where(
                        ReportGenerationDB.owner_id == owner_id,
                        ReportGenerationDB.status.in_(
                            [Status.QUEUED.value, Status.GENERATING.value],
                        ),
                    ),
                )
                if (
                    int(
                        pending or 0,
                    )
                    >= self.config.max_pending_per_owner
                ):
                    raise ReportGenerationConflictError()
                job = ReportGenerationDB(
                    id=str(
                        body.requestId,
                    ),
                    owner_id=owner_id,
                    request_id=str(
                        body.requestId,
                    ),
                    request_digest=digest,
                    model_id=model_id,
                    status=Status.QUEUED.value,
                    sequence=0,
                    payload=self.cipher.seal(
                        payload,
                    ),
                    snapshot=self.cipher.seal(
                        {},
                    ),
                    created_at=now,
                    expires_at=now
                    + timedelta(
                        seconds=self.config.retention_seconds,
                    ),
                    deadline_at=now
                    + timedelta(
                        seconds=self.config.queue_timeout_seconds,
                    ),
                )
                session.add(
                    job,
                )
                await session.flush()
                return self.response(
                    job,
                )
        except IntegrityError as error:
            raise ReportGenerationConflictError() from error

    async def get(
        self,
        owner_id: str,
        generation_id: str,
    ) -> USReportGenerationResponse:
        async with self.database.session() as session:
            job = await session.get(
                ReportGenerationDB,
                generation_id,
            )
            if (
                job is None
                or job.owner_id != owner_id
                or job.expires_at.replace(
                    tzinfo=UTC,
                )
                <= datetime.now(
                    UTC,
                )
            ):
                raise ReportGenerationNotFoundError()
            is_expired = not Status(
                job.status,
            ).is_terminal and job.deadline_at.replace(
                tzinfo=UTC,
            ) <= datetime.now(
                UTC,
            )
            response = self.response(
                job,
            )
        if is_expired:
            await self.finish(
                generation_id,
                error_code="generationTimeout",
            )
            return await self.get(
                owner_id,
                generation_id,
            )
        return response

    async def claim(
        self,
        operation_timeout: float,
    ) -> ReportGenerationDB | None:
        async with self.database.session() as session, session.begin():
            job = await session.scalar(
                select(
                    ReportGenerationDB,
                )
                .where(
                    ReportGenerationDB.status == Status.QUEUED.value,
                    ReportGenerationDB.deadline_at
                    > datetime.now(
                        UTC,
                    ),
                )
                .order_by(
                    ReportGenerationDB.created_at,
                )
                .with_for_update(
                    skip_locked=True,
                )
                .limit(
                    1,
                ),
            )
            if job is not None:
                job.status = Status.GENERATING.value
                job.sequence += 1
                job.deadline_at = datetime.now(
                    UTC,
                ) + timedelta(
                    seconds=operation_timeout + 5,
                )
            return job

    async def is_active(
        self,
        generation_id: str,
    ) -> bool:
        async with self.database.session() as session:
            status = await session.scalar(
                select(
                    ReportGenerationDB.status,
                ).where(
                    ReportGenerationDB.id == generation_id,
                ),
            )
            return status == Status.GENERATING.value

    async def preview(
        self,
        generation_id: str,
        preview: USReportPreviewResponse,
    ) -> None:
        async with self.database.session() as session, session.begin():
            job = await session.get(
                ReportGenerationDB,
                generation_id,
                with_for_update=True,
            )
            if job is None or job.status != Status.GENERATING.value:
                return
            job.snapshot = self.cipher.seal(
                {
                    "partialReport": preview.model_dump(
                        mode="json",
                    )
                },
            )
            job.sequence += 1

    async def finish(
        self,
        generation_id: str,
        *,
        report: USExaminationModelReportResponse | None = None,
        error_code: str | None = None,
    ) -> None:
        async with self.database.session() as session, session.begin():
            job = await session.get(
                ReportGenerationDB,
                generation_id,
                with_for_update=True,
            )
            if (
                job is None
                or Status(
                    job.status,
                ).is_terminal
            ):
                return
            status = Status.COMPLETED if report is not None else Status.FAILED
            if report is not None:
                job.snapshot = self.cipher.seal(
                    {
                        "report": report.model_dump(
                            mode="json",
                        ),
                        "partialReport": {
                            key: getattr(
                                report,
                                key,
                            )
                            for key in USReportPreviewResponse.model_fields
                        },
                    },
                )
            self._terminate(
                job,
                status,
                error_code,
            )
            usage = await session.get(
                BillingUsageDB,
                generation_id,
            )
            if usage is not None and usage.status == "pending":
                usage.status = "completed" if report is not None else "failed"

    async def cancel(
        self,
        owner_id: str,
        generation_id: str,
    ) -> USReportGenerationResponse:
        async with self.database.session() as session, session.begin():
            job = await session.get(
                ReportGenerationDB,
                generation_id,
                with_for_update=True,
            )
            if (
                job is None
                or job.owner_id != owner_id
                or job.expires_at.replace(
                    tzinfo=UTC,
                )
                <= datetime.now(
                    UTC,
                )
            ):
                raise ReportGenerationNotFoundError()
            if not Status(
                job.status,
            ).is_terminal:
                self._terminate(
                    job,
                    Status.CANCELLED,
                    "generationCancelled",
                )
                usage = await session.get(
                    BillingUsageDB,
                    generation_id,
                )
                if usage is not None and usage.status == "pending":
                    usage.status = "failed"
            return self.response(
                job,
            )

    async def clean(
        self,
    ) -> None:
        now = datetime.now(
            UTC,
        )
        async with self.database.session() as session, session.begin():
            jobs = (
                await session.scalars(
                    select(
                        ReportGenerationDB,
                    )
                    .where(
                        ReportGenerationDB.status.in_(
                            [Status.QUEUED.value, Status.GENERATING.value],
                        ),
                        ReportGenerationDB.deadline_at <= now,
                    )
                    .with_for_update(
                        skip_locked=True,
                    )
                    .limit(
                        100,
                    ),
                )
            ).all()
            for job in jobs:
                self._terminate(
                    job,
                    Status.FAILED,
                    "generationTimeout",
                )
                usage = await session.get(
                    BillingUsageDB,
                    job.id,
                )
                if usage is not None and usage.status == "pending":
                    usage.status = "failed"
            await session.execute(
                delete(
                    ReportGenerationDB,
                ).where(
                    ReportGenerationDB.expires_at <= now,
                ),
            )

    def response(
        self,
        job: ReportGenerationDB,
    ) -> USReportGenerationResponse:
        snapshot = self.cipher.open(
            job.snapshot,
        )
        return USReportGenerationResponse(
            modelId=job.model_id,
            generationId=UUID(
                job.id,
            ),
            status=Status(
                job.status,
            ),
            sequence=job.sequence,
            expiresAt=job.expires_at.replace(
                tzinfo=UTC,
            ),
            partialReport=USReportPreviewResponse.model_validate(
                snapshot.get(
                    "partialReport",
                    {},
                ),
            ),
            report=USExaminationModelReportResponse.model_validate(
                snapshot["report"],
            )
            if snapshot.get(
                "report",
            )
            else None,
            errorCode=job.error_code,
        )

    @staticmethod
    def _terminate(
        job: ReportGenerationDB,
        status: Status,
        code: str | None,
    ) -> None:
        job.status = status.value
        job.error_code = code
        job.payload = None
        job.sequence += 1
