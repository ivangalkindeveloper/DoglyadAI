from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request

from app.core.get_report_generation_service import get_report_generation_service
from app.core.get_request_language import get_request_language
from app.core.http_header import HttpHeader
from app.core.language_code import LanguageCode
from app.model.ultrasound.us_examination_model_report_response import USExaminationModelReportResponse
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.service.report_generation_service import ReportGenerationService

router = APIRouter()


@router.post("/generate_report", response_model=USExaminationModelReportResponse)
async def generate_report(
    body: USExaminationRequest,
    request: Request,
    service: Annotated[ReportGenerationService, Depends(get_report_generation_service)],
    language: Annotated[LanguageCode, Depends(get_request_language)],
) -> USExaminationModelReportResponse:
    return await service.generate(
        body,
        language_code=language,
        app_check_token=request.headers.get(HttpHeader.FIREBASE_APP_CHECK.value),
        request_id=request.state.request_id,
    )
