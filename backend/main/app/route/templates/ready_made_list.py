from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Response

from app.core.get_configuration_response_service import get_configuration_response_service
from app.core.get_request_language import get_request_language
from app.core.http_header import HttpHeader
from app.core.language_code import LanguageCode
from app.model.ultrasound.us_examination_ready_made_template_response import USExaminationReadyMadeTemplateResponse
from app.service.configuration_response_service import ConfigurationResponseService

router = APIRouter()


@router.get("/ready_made_list", response_model=list[USExaminationReadyMadeTemplateResponse])
async def ready_made_list(
    response: Response,
    service: Annotated[ConfigurationResponseService, Depends(get_configuration_response_service)],
    language: Annotated[LanguageCode, Depends(get_request_language)],
) -> list[USExaminationReadyMadeTemplateResponse]:
    response.headers[HttpHeader.CONTENT_LANGUAGE.value] = language.value
    response.headers[HttpHeader.VARY.value] = HttpHeader.ACCEPT_LANGUAGE.value
    return service.ready_made_templates(language)
