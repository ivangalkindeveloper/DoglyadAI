from __future__ import annotations

from fastapi import Request

from app.service.vllm_service import VLLMService


async def get_vllm_service(request: Request) -> VLLMService:
    service: VLLMService = request.app.state.vllm_service
    return service
