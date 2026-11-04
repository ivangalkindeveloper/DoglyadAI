from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.model.ultrasound.us_report_generation_response import USReportGenerationResponse
from app.service.report.report_generation_jobs import ReportGenerationJobs

router = APIRouter()


@router.get(
    "/{generation_id}",
    response_model=USReportGenerationResponse,
)
async def get_report_generation(
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
) -> USReportGenerationResponse:
    return await jobs.store.get(
        owner,
        str(
            generation_id,
        ),
    )
