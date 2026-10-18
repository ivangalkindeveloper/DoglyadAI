from __future__ import annotations

import logging
from datetime import UTC, datetime

from fastapi import APIRouter, HTTPException, Request

from app.core.get_application_locale_config import get_application_locale_config
from app.core.http_header import HttpHeader
from app.core.limiter import limiter
from app.core.resolve_examination_title import resolve_examination_title
from app.core.resolve_language import resolve_language
from app.core.resolve_neural_model import resolve_neural_model
from app.model.neural_model.neural_model_service_operation import NeuralModelServiceOperation
from app.model.ultrasound.us_examination_model_report_response import USExaminationModelReportResponse
from app.model.ultrasound.us_examination_report import USExaminationReport
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.prompt import PromptFactory
from app.schema.us_examination_report_structured_output import us_examination_report_structured_output
from app.service import NeuralModelService, NeuralModelServiceRequest
from app.service.validate_report_content import validate_report_content
from app.service.validate_report_remarks import validate_report_remarks

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/generate_report", response_model=USExaminationModelReportResponse)
@limiter.limit("30/minute")
async def generate_report(
    body: USExaminationRequest,
    request: Request,
) -> USExaminationModelReportResponse:
    language_code = resolve_language(
        request.headers.get(HttpHeader.ACCEPT_LANGUAGE.value), get_application_locale_config()
    )
    prompt_factory = PromptFactory(language_code)

    settings = body.neuralModelSettings
    examination = body.examinationData

    neural_model = resolve_neural_model(settings.selectedNeuralModelId)
    examination_title = resolve_examination_title(
        examination.usExaminationTypeId,
        language_code,
    )

    logger.info(
        "Report request: model=%s, lang=%s, exam=%s, photos=%d",
        neural_model.id,
        language_code.value,
        examination_title,
        len(examination.photos),
    )

    model_service: NeuralModelService = request.app.state.model_service
    response_text = await model_service.call(
        NeuralModelServiceRequest(
            operation=NeuralModelServiceOperation.GENERATE_REPORT,
            language_code=language_code,
            model_id=neural_model.id,
            system_prompt=prompt_factory.system_prompt(
                settings,
                is_recommendations_included=body.isRecommendationsIncluded,
                is_photo_remarks=body.isPhotoRemarks and bool(examination.photos),
                is_description_remarks=body.isDescriptionRemarks,
            ),
            prompt=prompt_factory.build_prompt(
                examination,
                examination_title,
                body.template,
            ),
            structured_output=us_examination_report_structured_output(
                is_recommendations_included=body.isRecommendationsIncluded,
                is_photo_remarks=body.isPhotoRemarks,
                is_description_remarks=body.isDescriptionRemarks,
                photo_ids=[photo.id for photo in examination.photos],
                language_code=language_code,
            ),
            temperature=settings.temperature,
            max_tokens=settings.maxTokens,
            photos=examination.photos,
            app_check_token=request.headers.get(HttpHeader.FIREBASE_APP_CHECK.value),
            request_id=request.state.request_id,
        )
    )

    try:
        report = USExaminationReport.model_validate_json(response_text)
        validate_report_content(report, examination, language_code=language_code)
        validate_report_remarks(report, body)
    except ValueError as error:
        logger.warning("Generated report does not match the response schema: %s", type(error).__name__)
        raise HTTPException(status_code=502, detail="Invalid report from inference service") from error

    return USExaminationModelReportResponse(
        date=datetime.now(UTC),
        modelId=neural_model.id,
        **report.model_dump(),
    )
