"""Exercise the deployed VLLMService in an isolated process, without changing HTTP auth."""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import time
from pathlib import Path

import httpx
from app.core.variables import Variables
from app.model.generation_request import GenerationRequest
from app.model.inference_server_config import InferenceServerConfig
from app.service.vllm_service import VLLMService


async def _run(args: argparse.Namespace) -> None:
    model = "google/medgemma-4b-it"
    original = json.loads(Path("/app/dgx-config/server.json").read_text())
    results = {"variant": args.variant, "boundary": "direct deployed VLLMService, not HTTP/App Check or main/iOS",
               "is_live_configuration_changed": False, "batches": []}
    schema = {"type": "object", "properties": {"caseId": {"type": "string"}, "description": {"type": "string"},
              "conclusion": {"type": "string"}}, "required": ["caseId", "description", "conclusion"], "additionalProperties": False}
    async with httpx.AsyncClient(trust_env=False) as client:
        for capacity, clients in [(1, 1), (1, 4), (2, 2), (4, 4), (8, 8)]:
            config = json.loads(json.dumps(original))
            config["generation"]["max_concurrent_requests"] = capacity
            variables = Variables(served_model_id=None, vllm_endpoints={model: args.url})
            service = VLLMService(client, variables, InferenceServerConfig.model_validate(config))

            async def request(index: int) -> dict:
                identifier = f"probe-{capacity}-{clients}-{index}"
                started = time.perf_counter()
                result = {"index": index, "is_success": False}
                try:
                    value = await service.generate(GenerationRequest(
                        modelId=model, maxTokens=256, temperature=0,
                        prompt=f"Синтетический тест, не данные пациента. caseId: {identifier}. "
                               "Печень обычных размеров, структура однородная. Желчный пузырь без конкрементов. "
                               "Почки без расширения чашечно-лоханочной системы. Свободной жидкости нет. "
                               "Верни JSON. Точно перенеси caseId. description: подробное описание наблюдений в трёх предложениях. "
                               "conclusion: одно предложение. Не добавляй измерения.",
                        structuredOutput=json.dumps(schema)))
                    parsed = json.loads(value)
                    if set(parsed) != set(schema["required"]) or not all(isinstance(v, str) for v in parsed.values()):
                        raise ValueError("Schema mismatch")
                    if parsed["caseId"] != identifier:
                        raise ValueError("Case mismatch")
                    result.update(is_success=True, is_schema_valid=True, is_case_match=True,
                                  output_sha256=hashlib.sha256(value.encode()).hexdigest())
                except Exception as error:
                    result["error_type"] = type(error).__name__
                result["seconds"] = time.perf_counter()-started
                return result

            started = time.perf_counter()
            samples = await asyncio.gather(*[request(i) for i in range(clients)])
            batch = {"service_capacity": capacity, "clients": clients, "wall_seconds": time.perf_counter()-started, "samples": samples}
            results["batches"].append(batch)
            Path(args.output).write_text(json.dumps(results, indent=2))
            print(json.dumps({"capacity": capacity, "clients": clients, "success": sum(r["is_success"] for r in samples),
                              "errors": [r.get("error_type") for r in samples if not r["is_success"]]}), flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--variant", required=True)
    parser.add_argument("--output", required=True)
    asyncio.run(_run(parser.parse_args()))


if __name__ == "__main__":
    main()
