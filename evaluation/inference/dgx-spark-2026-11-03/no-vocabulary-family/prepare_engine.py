"""Build private engine payloads without starting an HTTP application."""
from __future__ import annotations

import asyncio
import json
from pathlib import Path
import sys

import httpx

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'backend/inference'))
from app.core.variables import Variables
from app.model.generation_request import GenerationRequest
from app.model.inference_server_config import InferenceServerConfig
from app.service.vllm_service import VLLMService


async def main() -> None:
    cases = json.load(sys.stdin)
    routes = {c['model']: 'http://127.0.0.1:8000' for c in cases}
    config = InferenceServerConfig.model_validate_json((ROOT / 'backend/inference/config/server.json').read_text())
    async with httpx.AsyncClient() as client:
        service = VLLMService(client, Variables(served_model_id=None, vllm_endpoints=routes), config)
        for c in cases:
            _, payload = service._prepare(GenerationRequest.model_validate(c['transport_request']))
            payload['stream'] = True
            payload['seed'] = c.pop('seed')
            assert 'top_k' not in payload and 'top_p' not in payload
            c['payload'] = payload
            c['actual_inference_payload'] = True
    print(json.dumps(cases, ensure_ascii=False))


if __name__ == '__main__':
    asyncio.run(main())
