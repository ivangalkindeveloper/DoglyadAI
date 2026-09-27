from __future__ import annotations

from fastapi import APIRouter, Request, Response

from app.core.config import resolve_neural_models_document
from app.core.limiter import limiter
from app.route.config_document import config_document_response

router = APIRouter()


@router.get("/examination_neural_models")
@limiter.limit("60/minute")
async def examination_neural_models(request: Request) -> Response:
    return config_document_response(request, resolve_neural_models_document)
