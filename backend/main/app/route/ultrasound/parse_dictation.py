from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Request
from pydantic import ValidationError

from app.core.config import (
    get_application_locale_config,
    get_voice_parsing_config,
    resolve_examination_title,
    resolve_neural_model,
)
from app.core.http_header import HttpHeader
from app.core.limiter import limiter
from app.core.locale import resolve_language
from app.model.inference.inference_request import InferenceRequest
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.model.ultrasound.us_voice_form_parse_request import USVoiceFormParseRequest
from app.model.ultrasound.us_voice_form_parse_response import USVoiceFormParseResponse
from app.prompt.voice_form import voice_form_prompt, voice_form_system_prompt
from app.service import ModelService
from app.service.voice_form_validation import validate_voice_form_generation

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/parse_dictation", response_model=USVoiceFormParseResponse)
@limiter.limit("30/minute")
async def parse_dictation(body: USVoiceFormParseRequest, request: Request) -> USVoiceFormParseResponse:
    language = resolve_language(request.headers.get(HttpHeader.ACCEPT_LANGUAGE.value), get_application_locale_config())
    title = resolve_examination_title(body.usExaminationTypeId, language)
    config = get_voice_parsing_config()
    model = resolve_neural_model(config.modelId)
    logger.info(
        "Voice parse request: model=%s, language=%s, examination_type=%s, transcript_chars=%d",
        model.id,
        language.value,
        body.usExaminationTypeId,
        len(body.transcript),
    )

    service: ModelService = request.app.state.model_service
    response_text = await service.call(
        InferenceRequest(
            model_id=model.id,
            system_prompt=voice_form_system_prompt(language),
            prompt=voice_form_prompt(title, body.transcript),
            structured_output=USVoiceFormGeneration.structured_output(),
            temperature=0,
            max_tokens=config.maxTokens,
            app_check_token=request.headers.get(HttpHeader.FIREBASE_APP_CHECK.value),
            request_id=request.state.request_id,
        )
    )
    try:
        generated = USVoiceFormGeneration.model_validate_json(response_text)
    except ValidationError as error:
        logger.warning("Voice parse response failed schema validation: %s", type(error).__name__)
        raise HTTPException(status_code=502, detail="Invalid voice parse response") from error
    return validate_voice_form_generation(generated, body.transcript)
