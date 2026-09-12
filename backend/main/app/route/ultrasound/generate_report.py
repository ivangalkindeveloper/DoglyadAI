from __future__ import annotations

import logging
from datetime import UTC, datetime

from fastapi import APIRouter, HTTPException, Request
from pydantic import ValidationError

from app.core.app_check import APP_CHECK_HEADER
from app.core.config import resolve_examination_title, resolve_neural_model
from app.core.limiter import limiter
from app.model.ultrasound.us_examination_report import (
    USExaminationModelReport,
    USExaminationReport,
    us_examination_report_structured_output,
)
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.prompt import resolve_prompt_factory
from app.service import InferenceRequest, ModelService

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/generate_report", response_model=USExaminationModelReport)
@limiter.limit("30/minute")
async def generate_report(
    body: USExaminationRequest,
    request: Request,
) -> USExaminationModelReport:
    accept_language = request.headers.get("accept-language", "en")
    language_code = accept_language.split("_")[0].strip()
    prompt_factory = resolve_prompt_factory(language_code)

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
        language_code,
        examination_title,
        len(examination.photos),
    )

    model_service: ModelService = request.app.state.model_service
    response_text = await model_service.call(
        InferenceRequest(
            neural_model=neural_model,
            settings=settings,
            language_code=language_code,
            system_prompt=prompt_factory.system_prompt(
                settings,
                include_recommendations=body.includeRecommendations,
            ),
            prompt=prompt_factory.build_prompt(
                examination,
                examination_title,
                body.template,
            ),
            structured_output=us_examination_report_structured_output(
                include_recommendations=body.includeRecommendations
            ),
            photos=examination.photos,
            app_check_token=request.headers.get(APP_CHECK_HEADER),
        )
    )

    try:
        report = USExaminationReport.model_validate_json(response_text)
    except ValidationError as error:
        logger.exception("Generated report does not match the response schema: %s", error)
        raise HTTPException(status_code=502, detail="Invalid report from inference service") from error

    return USExaminationModelReport(
        date=datetime.now(UTC),
        modelId=neural_model.id,
        **report.model_dump(),
    )
