from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.get_vllm_service import get_vllm_service
from app.model.generation_request import GenerationRequest
from app.model.generation_response import GenerationResponse
from app.service.vllm_service import VLLMService

router = APIRouter()


@router.post(
    "/generation",
    response_model=GenerationResponse,
)
async def generation(
    body: GenerationRequest,
    service: Annotated[
        VLLMService,
        Depends(
            get_vllm_service,
        ),
    ],
) -> GenerationResponse:
    value = await service.generate(
        body,
    )
    return GenerationResponse(
        modelId=body.modelId,
        response=value,
    )
