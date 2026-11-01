from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Response

from app.core.application.service_dependencies import ServiceDependencies
from app.core.localization.language_code import LanguageCode
from app.core.localization.localization_dependencies import LocalizationDependencies
from app.route.config_document_response import config_document_response
from app.service.configuration.configuration_response_service import ConfigurationResponseService

router = APIRouter()


@router.get(
    "/examination_neural_models",
)
async def examination_neural_models(
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
) -> Response:
    return config_document_response(
        service.neural_models_document(
            language,
        ),
        language,
    )
