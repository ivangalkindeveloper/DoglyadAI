from __future__ import annotations

from fastapi import APIRouter, Request, Response

from app.core.limiter import limiter
from app.route.config_document import config_document_response

router = APIRouter()


@router.get("/examination_types")
@limiter.limit("60/minute")
async def examination_types(request: Request) -> Response:
    del request  # only the rate limiter needs it
    return config_document_response("ultrasound_examination_types.json")
