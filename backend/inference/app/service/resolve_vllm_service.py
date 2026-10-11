from __future__ import annotations

import app.service.init_services as _services
from app.service.vllm_service import VLLMService


def resolve_vllm_service() -> VLLMService:
    if _services._service is None:
        raise RuntimeError("vLLM service is not initialized")
    return _services._service
