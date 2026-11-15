from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.core.http.http_header import HttpHeader
from app.core.localization.language_code import LanguageCode
from app.core.localization.localization_dependencies import LocalizationDependencies
from app.model.ultrasound.us_audio_parse_request import USAudioParseRequest
from app.model.ultrasound.us_audio_parse_response import USAudioParseResponse
from app.service.dictation.audio_parsing_service import AudioParsingService

router = APIRouter(
    dependencies=[
        Depends(
            BillingDependencies.dictation_access,
        )
    ],
)


@router.post(
    "/parse_audio",
    response_model=USAudioParseResponse,
)
async def parse_audio(
    parameters: Annotated[USAudioParseRequest, Query()],
    request: Request,
    service: Annotated[
        AudioParsingService,
        Depends(
            ServiceDependencies.audio_parsing,
        ),
    ],
    language: Annotated[
        LanguageCode,
        Depends(
            LocalizationDependencies.language,
        ),
    ],
) -> USAudioParseResponse:
    return await service.parse(
        await request.body(),
        parameters,
        language=language,
        content_type=request.headers.get(
            "Content-Type",
        ),
        app_check_token=request.headers.get(
            HttpHeader.FIREBASE_APP_CHECK.value,
        ),
        request_id=request.state.request_id,
    )
