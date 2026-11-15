from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.core.http.http_header import HttpHeader
from app.core.localization.language_code import LanguageCode
from app.core.localization.localization_dependencies import LocalizationDependencies
from app.model.ultrasound.us_voice_form_parse_request import USVoiceFormParseRequest
from app.model.ultrasound.us_voice_form_parse_response import USVoiceFormParseResponse
from app.service.dictation.transcript_parsing_service import TranscriptParsingService

router = APIRouter(
    dependencies=[
        Depends(
            BillingDependencies.dictation_access,
        )
    ],
)


@router.post(
    "/parse_transcript",
    response_model=USVoiceFormParseResponse,
)
async def parse_transcript(
    body: USVoiceFormParseRequest,
    request: Request,
    service: Annotated[
        TranscriptParsingService,
        Depends(
            ServiceDependencies.transcript_parsing,
        ),
    ],
    language: Annotated[
        LanguageCode,
        Depends(
            LocalizationDependencies.language,
        ),
    ],
) -> USVoiceFormParseResponse:
    return await service.parse(
        body,
        language=language,
        app_check_token=request.headers.get(
            HttpHeader.FIREBASE_APP_CHECK.value,
        ),
        request_id=request.state.request_id,
    )
