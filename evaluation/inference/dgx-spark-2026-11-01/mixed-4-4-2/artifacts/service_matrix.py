"""Isolated service instances emulate per-model limits without changing the live API."""

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
    targets = json.loads(Path(args.targets).read_text())
    original = json.loads(Path("/app/dgx-config/server.json").read_text())
    schema = {
        "type": "object",
        "properties": {
            "caseId": {"type": "string"},
            "description": {"type": "string"},
            "conclusion": {"type": "string"},
        },
        "required": ["caseId", "description", "conclusion"],
        "additionalProperties": False,
    }
    result = {
        "boundary": "Three isolated VLLMService instances with different capacities; no HTTP/App Check bypass and no live configuration changes",
        "waves": [],
    }
    async with httpx.AsyncClient(trust_env=False) as client:
        services = {}
        for t in targets:
            config = json.loads(json.dumps(original))
            config["generation"]["max_concurrent_requests"] = t["concurrency"]
            services[t["model"]] = VLLMService(
                client,
                Variables(served_model_id=None, vllm_endpoints={t["model"]: t["url"]}),
                InferenceServerConfig.model_validate(config),
            )
        for wave in range(3):
            gate = asyncio.Event()

            async def request(t: dict, index: int) -> dict:
                identifier = f"test-{t['key']}-{wave}-{index}"
                await gate.wait()
                start = time.perf_counter()
                row = {"model": t["model"], "index": index, "is_success": False}
                try:
                    text = await services[t["model"]].generate(
                        GenerationRequest(
                            modelId=t["model"],
                            temperature=0,
                            maxTokens=256,
                            structuredOutput=json.dumps(schema),
                            prompt=f"Синтетический тест, не данные пациента. caseId: {identifier}. Печень обычных размеров, структура однородная. "
                            "Желчный пузырь без конкрементов. Почки без расширения чашечно-лоханочной системы. Свободной жидкости нет. "
                            "Верни JSON. Точно перенеси caseId. description: три предложения по наблюдениям. conclusion: одно предложение.",
                        )
                    )
                    value = json.loads(text)
                    if (
                        set(value) != set(schema["required"])
                        or not all(isinstance(v, str) for v in value.values())
                        or value["caseId"] != identifier
                    ):
                        raise ValueError("Invalid structured result")
                    row.update(
                        is_success=True,
                        output_sha256=hashlib.sha256(text.encode()).hexdigest(),
                    )
                except Exception as error:
                    row["error_type"] = type(error).__name__
                row["seconds"] = time.perf_counter() - start
                return row

            tasks = [
                asyncio.create_task(request(t, i))
                for t in targets
                for i in range(t["concurrency"])
            ]
            start = time.perf_counter()
            gate.set()
            samples = await asyncio.gather(*tasks)
            result["waves"].append(
                {
                    "wave": wave,
                    "is_measured": wave > 0,
                    "seconds": time.perf_counter() - start,
                    "samples": samples,
                }
            )
            Path(args.output).write_text(json.dumps(result, indent=2))
            print(
                json.dumps(
                    {
                        "wave": wave,
                        "success": sum(r["is_success"] for r in samples),
                        "requests": len(samples),
                    }
                ),
                flush=True,
            )
            if not all(r["is_success"] for r in samples):
                raise RuntimeError("Service wave failed")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--targets", required=True)
    parser.add_argument("--output", required=True)
    asyncio.run(_run(parser.parse_args()))


if __name__ == "__main__":
    main()
