from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.service.report.report_generation_jobs import ReportGenerationJobs

router = APIRouter()


@router.get(
    "/{generation_id}/events",
)
async def stream_report_generation(
    generation_id: UUID,
    owner: Annotated[
        str,
        Depends(
            BillingDependencies.owner,
        ),
    ],
    jobs: Annotated[
        ReportGenerationJobs,
        Depends(
            ServiceDependencies.report_jobs,
        ),
    ],
) -> StreamingResponse:
    await jobs.store.get(
        owner,
        str(
            generation_id,
        ),
    )
    return StreamingResponse(
        jobs.events(
            owner,
            str(
                generation_id,
            ),
        ),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-store", "X-Accel-Buffering": "no"},
    )
