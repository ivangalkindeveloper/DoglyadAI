from __future__ import annotations

import httpx

from app.service.vllm_service import VLLMService

_service: VLLMService | None = None


def init_services(http_client: httpx.AsyncClient) -> None:
    global _service
    _service = VLLMService(http_client)
