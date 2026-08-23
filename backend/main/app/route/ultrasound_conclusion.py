from __future__ import annotations

import logging
from datetime import UTC, datetime

from fastapi import APIRouter, Request

from app.core.app_check import APP_CHECK_HEADER
from app.core.config import (
    resolve_examination_title,
    resolve_neural_model,
)
from app.core.limiter import limiter
from app.model.ultrasound.us_examination_model_conclusion import USExaminationModelConclusion
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.prompt import resolve_prompt_factory
from app.service import InferenceRequest, ModelService

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/ultrasound_conclusion", response_model=USExaminationModelConclusion)
@limiter.limit("30/minute")
async def ultrasound_conclusion(
    body: USExaminationRequest,
    request: Request,
) -> USExaminationModelConclusion:
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
        "Request: model=%s, lang=%s, exam=%s, photos=%d",
        neural_model.id,
        language_code,
        examination_title,
        len(examination.photos),
    )

    # Which services stand behind this is decided once at startup; the route just
    # calls the one it was handed. Same composition in every environment.
    model_service: ModelService = request.app.state.model_service
    response_text = await model_service.call(
        InferenceRequest(
            neural_model=neural_model,
            settings=settings,
            language_code=language_code,
            system_prompt=prompt_factory.system_prompt(settings),
            prompt=prompt_factory.build_prompt(
                examination,
                examination_title,
                body.template,
            ),
            photos=examination.photos,
            # Verified by the router dependency; relayed unchanged so the GPU VM can
            # verify it too — reaching it over the network is not on its own enough
            # to use it.
            app_check_token=request.headers.get(APP_CHECK_HEADER),
        )
    )

    return USExaminationModelConclusion(
        date=datetime.now(UTC),
        modelId=neural_model.id,
        response=response_text,
    )
