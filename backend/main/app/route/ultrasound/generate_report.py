from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.core.billing.billing_request_guard import BillingRequestGuard
from app.core.http.http_header import HttpHeader
from app.core.localization.language_code import LanguageCode
from app.core.localization.localization_dependencies import LocalizationDependencies
from app.model.ultrasound.us_examination_model_report_response import USExaminationModelReportResponse
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.service.report.report_generation_service import ReportGenerationService

router = APIRouter()


@router.post(
    "/generate_report",
    response_model=USExaminationModelReportResponse,
)
async def generate_report(
    body: USExaminationRequest,
    request: Request,
    service: Annotated[
        ReportGenerationService,
        Depends(
            ServiceDependencies.report_generation,
        ),
    ],
    language: Annotated[
        LanguageCode,
        Depends(
            LocalizationDependencies.language,
        ),
    ],
    billing: Annotated[
        BillingRequestGuard,
        Depends(
            BillingDependencies.report_access,
        ),
    ],
) -> USExaminationModelReportResponse:
    async with billing:
        return await service.generate(
            body,
            language_code=language,
            app_check_token=request.headers.get(
                HttpHeader.FIREBASE_APP_CHECK.value,
            ),
            request_id=request.state.request_id,
        )
