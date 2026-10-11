from __future__ import annotations

from fastapi import APIRouter, Depends, Request, Response

from app.core.limiter import limiter
from app.core.resolve_l10n_document import resolve_l10n_document
from app.core.verify_app_check import verify_app_check
from app.route.config_document_response import config_document_response

# Localization has its own versioned router, independently of the application API.
router_v1 = APIRouter(prefix="/v1", dependencies=[Depends(verify_app_check)])


@router_v1.get("/l10n")
@limiter.limit("30/minute")
async def l10n(request: Request) -> Response:
    return config_document_response(request, resolve_l10n_document)
