from __future__ import annotations

import logging

from fastapi import APIRouter, Request

from app.core.config import ready_made_templates
from app.core.limiter import limiter
from app.model.ultrasound.us_examination_ready_made_template import USExaminationReadyMadeTemplate

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/ready_made_list", response_model=list[USExaminationReadyMadeTemplate])
@limiter.limit("30/minute")
async def ready_made_list(request: Request) -> list[USExaminationReadyMadeTemplate]:
    del request  # only the rate limiter needs it
    logger.info("Ready-made templates served: count=%d", len(ready_made_templates))
    return ready_made_templates
