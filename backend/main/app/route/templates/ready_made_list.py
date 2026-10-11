from __future__ import annotations

import logging

from fastapi import APIRouter, Request, Response

from app.core.get_application_locale_config import get_application_locale_config
from app.core.http_header import HttpHeader
from app.core.limiter import limiter
from app.core.resolve_language import resolve_language
from app.core.resolve_ready_made_templates import resolve_ready_made_templates
from app.model.ultrasound.us_examination_ready_made_template_response import (
    USExaminationReadyMadeTemplateResponse,
)

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/ready_made_list", response_model=list[USExaminationReadyMadeTemplateResponse])
@limiter.limit("30/minute")
async def ready_made_list(request: Request, response: Response) -> list[USExaminationReadyMadeTemplateResponse]:
    language = resolve_language(request.headers.get(HttpHeader.ACCEPT_LANGUAGE.value), get_application_locale_config())
    response.headers[HttpHeader.CONTENT_LANGUAGE.value] = language.value
    response.headers[HttpHeader.VARY.value] = HttpHeader.ACCEPT_LANGUAGE.value
    templates = resolve_ready_made_templates(language)
    logger.info("Ready-made templates served: count=%d", len(templates))
    return templates
