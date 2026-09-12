from __future__ import annotations

import logging

from fastapi import APIRouter

from app.model.generation_request import GenerationRequest
from app.model.generation_response import GenerationResponse
from app.service import resolve_vllm_service

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/generation", response_model=GenerationResponse)
async def generation(body: GenerationRequest) -> GenerationResponse:
    """Generates structured content with the model deployed on this VM."""
    service = resolve_vllm_service()
    value = await service.generate(body)
    return GenerationResponse(modelId=service.model_id, response=value)
