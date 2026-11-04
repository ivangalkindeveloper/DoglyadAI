"""Run synthetic completion checks inside the candidate or deployed inference image."""

from __future__ import annotations

import argparse
import asyncio
import json
from pathlib import Path
import sys
import time

import httpx

sys.path.insert(0, "/app")
from app.core.variables import Variables
from app.model.generation_request import GenerationRequest
from app.model.inference_server_config import InferenceServerConfig
from app.service.vllm_service import VLLMService

ENDPOINTS = {
    "google/medgemma-4b-it": "http://vllm_medgemma_4b:8000",
    "google/medgemma-1.5-4b-it": "http://vllm_medgemma_15_4b:8000",
    "google/medgemma-27b-it": "http://vllm_medgemma_27b:8000",
}


async def run(args: argparse.Namespace) -> None:
    variables = Variables(served_model_id=None, vllm_endpoints=ENDPOINTS)
    config = InferenceServerConfig.model_validate_json(
        (variables.configuration_directory / "server.json").read_text()
    )
    if args.cases:
        cases = [
            case
            for case in json.loads(Path(args.cases).read_text())
            if not case["name"].startswith("forced-")
        ]
    else:
        cases = []
        for model in ENDPOINTS:
            for method, expected in (("generate", {"ok": True}), ("stream", [True])):
                cases.append(
                    {
                        "name": f"{model}-{method}",
                        "method": method,
                        "expected": expected,
                        "request": {
                            "modelId": model,
                            "prompt": "Return exactly this JSON: "
                            + json.dumps(expected),
                            "structuredOutput": json.dumps({"const": expected}),
                            "temperature": 0,
                            "maxTokens": 64,
                        },
                    }
                )
    async with httpx.AsyncClient(trust_env=False) as client:
        service = VLLMService(client, variables, config)
        for case in cases:
            started = time.monotonic()
            result = {
                "name": case["name"],
                "method": case["method"],
                "model": case["request"]["modelId"],
                "format": "native_compact",
            }
            try:
                request = GenerationRequest.model_validate(case["request"])
                if case["method"] == "generate":
                    text = await service.generate(request)
                else:
                    text = "".join([part async for part in service.stream(request)])
                value = json.loads(text)
                if "expected" in case:
                    assert value == case["expected"]
                result.update(is_success=True, valid_json=True, text=text)
            except Exception as error:
                result.update(
                    is_success=False,
                    error_code=getattr(error, "code", type(error).__name__),
                )
            result["seconds"] = round(time.monotonic() - started, 3)
            for _ in range(20):
                metrics = (
                    await client.get(ENDPOINTS[result["model"]] + "/metrics")
                ).text
                counters = [
                    float(line.split()[-1])
                    for line in metrics.splitlines()
                    if line.startswith(
                        ("vllm:num_requests_running{", "vllm:num_requests_waiting{")
                    )
                ]
                assert len(counters) >= 2
                active = sum(counters)
                if active == 0:
                    break
                await asyncio.sleep(0.1)
            result["active_engine_requests_after_close"] = active
            print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cases")
    asyncio.run(run(parser.parse_args()))
