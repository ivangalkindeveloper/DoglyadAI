from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Response

from app.core.get_configuration_response_service import get_configuration_response_service
from app.core.get_request_language import get_request_language
from app.core.language_code import LanguageCode
from app.route.config_document_response import config_document_response
from app.service.configuration_response_service import ConfigurationResponseService

router = APIRouter()


@router.get("/examination_types")
async def examination_types(
    service: Annotated[ConfigurationResponseService, Depends(get_configuration_response_service)],
    language: Annotated[LanguageCode, Depends(get_request_language)],
) -> Response:
    return config_document_response(service.examination_types_document(language), language)
