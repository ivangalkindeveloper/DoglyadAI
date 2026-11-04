from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.core.http.http_header import HttpHeader
from app.core.localization.language_code import LanguageCode
from app.core.localization.localization_dependencies import LocalizationDependencies
from app.model.ultrasound.us_report_generation_request import USReportGenerationRequest
from app.model.ultrasound.us_report_generation_response import USReportGenerationResponse
from app.service.report.report_generation_jobs import ReportGenerationJobs

router = APIRouter()


@router.post(
    "",
    status_code=202,
    response_model=USReportGenerationResponse,
)
async def start_report_generation(
    body: USReportGenerationRequest,
    request: Request,
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
    language: Annotated[
        LanguageCode,
        Depends(
            LocalizationDependencies.language,
        ),
    ],
) -> USReportGenerationResponse:
    return await jobs.start(
        owner,
        body,
        language=language,
        app_check_token=request.headers.get(
            HttpHeader.FIREBASE_APP_CHECK.value,
        ),
        request_id=request.state.request_id,
    )
