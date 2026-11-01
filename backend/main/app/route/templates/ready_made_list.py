from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Response

from app.core.application.service_dependencies import ServiceDependencies
from app.core.http.http_header import HttpHeader
from app.core.localization.language_code import LanguageCode
from app.core.localization.localization_dependencies import LocalizationDependencies
from app.model.ultrasound.us_examination_ready_made_template_response import USExaminationReadyMadeTemplateResponse
from app.service.configuration.configuration_response_service import ConfigurationResponseService

router = APIRouter()


@router.get(
    "/ready_made_list",
    response_model=list[USExaminationReadyMadeTemplateResponse],
)
async def ready_made_list(
    response: Response,
    service: Annotated[
        ConfigurationResponseService,
        Depends(
            ServiceDependencies.configuration_responses,
        ),
    ],
    language: Annotated[
        LanguageCode,
        Depends(
            LocalizationDependencies.language,
        ),
    ],
) -> list[USExaminationReadyMadeTemplateResponse]:
    response.headers[HttpHeader.CONTENT_LANGUAGE.value] = language.value
    response.headers[HttpHeader.VARY.value] = HttpHeader.ACCEPT_LANGUAGE.value
    return service.ready_made_templates(
        language,
    )
