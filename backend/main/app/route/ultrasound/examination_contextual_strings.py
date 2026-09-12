from __future__ import annotations

from fastapi import APIRouter, Request, Response

from app.core.limiter import limiter
from app.route.config_document import config_document_response

router = APIRouter()


@router.get("/examination_contextual_strings")
@limiter.limit("60/minute")
async def examination_contextual_strings(request: Request) -> Response:
    del request  # only the rate limiter needs it
    return config_document_response("ultrasound_examination_contextual_strings.json")
