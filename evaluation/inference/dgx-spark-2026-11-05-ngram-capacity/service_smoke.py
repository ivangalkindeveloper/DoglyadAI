"""Run inside the existing backend image: adapter integration, not HTTP auth."""

import asyncio
import json
from pathlib import Path
import sys
import time

import httpx
import jsonschema

from app.core.variables import Variables
from app.model.generation_request import GenerationRequest
from app.model.inference_server_config import InferenceServerConfig
from app.service.vllm_service import VLLMService


async def main():
    root = Path(sys.argv[1])
    variables = Variables()
    config = InferenceServerConfig.model_validate_json(
        (variables.configuration_directory / "server.json").read_text()
    )
    cases = {
        model: next(
            c
            for c in json.loads((root / f"cases-{model}.json").read_text())
            if c["id"] == "report-greedy-0"
        )
        for model in ["4b", "15-4b", "27b"]
    }
    async with httpx.AsyncClient(timeout=config.vllm.timeout()) as client:
        service = VLLMService(client, variables, config)
        start = asyncio.Event()

        async def perform(model, number):
            case = cases[model]
            request = GenerationRequest.model_validate(case["transport_request"])
            request = request.model_copy(update={"temperature": 0.0})
            await start.wait()
            began = time.perf_counter()
            first = None
            method = "stream" if number % 2 == 0 else "generate"
            try:
                if method == "stream":
                    parts = []
                    async for part in service.stream(request):
                        if part and first is None:
                            first = time.perf_counter() - began
                        parts.append(part)
                    text = "".join(parts)
                else:
                    text = await service.generate(request)
                value = json.loads(text)
                jsonschema.validate(value, case["schema"])
                return {
                    "model": model,
                    "client": number,
                    "method": method,
                    "seconds": time.perf_counter() - began,
                    "ttft": first,
                    "schema_valid": True,
                    "text": text,
                }
            except Exception as error:
                return {
                    "model": model,
                    "client": number,
                    "method": method,
                    "seconds": time.perf_counter() - began,
                    "error": type(error).__name__,
                    "code": getattr(error, "code", None),
                }

        tasks = [
            asyncio.create_task(perform(model, i))
            for i in range(config.generation.max_concurrent_requests)
            for model in cases
        ]
        start.set()
        rows = await asyncio.gather(*tasks)
    result = {
        "api_capacity_per_model": config.generation.max_concurrent_requests,
        "operation_timeout_seconds": config.vllm.operation_timeout_seconds,
        "authenticated_http_test": False,
        "requests": rows,
    }
    print(json.dumps(result, ensure_ascii=False))
    assert all(
        r.get("schema_valid") and r["seconds"] < config.vllm.operation_timeout_seconds
        for r in rows
    )


if __name__ == "__main__":
    asyncio.run(main())
