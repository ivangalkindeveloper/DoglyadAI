from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request

from app.core.get_dictation_parsing_service import get_dictation_parsing_service
from app.core.get_request_language import get_request_language
from app.core.http_header import HttpHeader
from app.core.language_code import LanguageCode
from app.model.ultrasound.us_voice_form_parse_request import USVoiceFormParseRequest
from app.model.ultrasound.us_voice_form_parse_response import USVoiceFormParseResponse
from app.service.dictation_parsing_service import DictationParsingService

router = APIRouter()


@router.post("/parse_dictation", response_model=USVoiceFormParseResponse)
async def parse_dictation(
    body: USVoiceFormParseRequest,
    request: Request,
    service: Annotated[DictationParsingService, Depends(get_dictation_parsing_service)],
    language: Annotated[LanguageCode, Depends(get_request_language)],
) -> USVoiceFormParseResponse:
    return await service.parse(
        body,
        language=language,
        app_check_token=request.headers.get(HttpHeader.FIREBASE_APP_CHECK.value),
        request_id=request.state.request_id,
    )
