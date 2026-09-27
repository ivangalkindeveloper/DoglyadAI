from __future__ import annotations

from fastapi import APIRouter, Request, Response

from app.core.config import resolve_application_config_document
from app.core.limiter import limiter
from app.route.config_document import config_document_response

router = APIRouter()


@router.get("/application_config")
@limiter.limit("60/minute")
async def application_config(request: Request) -> Response:
    return config_document_response(request, resolve_application_config_document)
