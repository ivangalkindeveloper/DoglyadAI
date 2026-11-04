"""Exercise the updated inference reader against live private DGX engines."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path
import subprocess
import sys
import time

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "backend/inference"))
from app.core.variables import Variables
from app.model.generation_request import GenerationRequest
from app.model.inference_server_config import InferenceServerConfig
from app.service.vllm_service import VLLMService
from whitespace_transport import WhitespaceTransport

ROOT = Path(__file__).resolve().parents[3]
DIRECTORY = Path(__file__).parent

ENDPOINTS = {
    "google/medgemma-4b-it": "http://127.0.0.1:18300",
    "google/medgemma-1.5-4b-it": "http://127.0.0.1:18301",
    "google/medgemma-27b-it": "http://127.0.0.1:18302",
}


async def run() -> None:
    variables = Variables(served_model_id=None, vllm_endpoints=ENDPOINTS)
    config = InferenceServerConfig.model_validate_json(
        (ROOT / "backend/inference/config/server.json").read_text()
    )
    cases = json.loads((DIRECTORY / "completion-cases.json").read_text())
    async with httpx.AsyncClient(timeout=10, trust_env=False) as control:
        for _ in range(20):
            try:
                response = await control.get(
                    ENDPOINTS["google/medgemma-4b-it"] + "/health"
                )
                response.raise_for_status()
                break
            except httpx.HTTPError:
                await asyncio.sleep(0.2)
        with (DIRECTORY / "completion-live-results.jsonl").open("w") as output:
            for case in cases:
                started = time.monotonic()
                result = {
                    "name": case["name"],
                    "method": case["method"],
                    "model": case["request"]["modelId"],
                    "forced_min_tokens": case.get("min_tokens"),
                }
                async with httpx.AsyncClient(
                    transport=WhitespaceTransport(case), trust_env=False
                ) as client:
                    service = VLLMService(client, variables, config)
                    try:
                        request = GenerationRequest.model_validate(case["request"])
                        if case["method"] == "generate":
                            text = await service.generate(request)
                        else:
                            text = "".join(
                                [part async for part in service.stream(request)]
                            )
                        json.loads(text)
                        result.update(is_success=True, text=text, valid_json=True)
                    except Exception as error:
                        result.update(
                            is_success=False,
                            error_code=getattr(error, "code", type(error).__name__),
                        )
                result["seconds"] = round(time.monotonic() - started, 3)
                for _ in range(20):
                    metrics = (
                        await control.get(ENDPOINTS[result["model"]] + "/metrics")
                    ).text
                    counters = [
                        float(line.split()[-1])
                        for line in metrics.splitlines()
                        if line.startswith(
                            ("vllm:num_requests_running{", "vllm:num_requests_waiting{")
                        )
                    ]
                    assert len(counters) >= 2, (
                        "Expected vLLM request counters are absent"
                    )
                    active = sum(counters)
                    if active == 0:
                        break
                    await asyncio.sleep(0.1)
                result["active_engine_requests_after_close"] = active
                output.write(json.dumps(result, ensure_ascii=False) + "\n")
                output.flush()
                print(
                    json.dumps(
                        {k: v for k, v in result.items() if k != "text"},
                        ensure_ascii=False,
                    ),
                    flush=True,
                )


def main() -> None:
    tunnel = subprocess.Popen(
        [
            "ssh",
            "-NT",
            "-i",
            str(Path.home() / ".ssh/doglyad-inference"),
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=5",
            "-o",
            "ExitOnForwardFailure=yes",
            "-L",
            "127.0.0.1:18300:172.21.0.4:8000",
            "-L",
            "127.0.0.1:18301:172.21.0.2:8000",
            "-L",
            "127.0.0.1:18302:172.21.0.3:8000",
            "ivangalkindeveloper@192.168.0.29",
        ]
    )
    try:
        asyncio.run(run())
    finally:
        tunnel.terminate()
        tunnel.wait(timeout=10)


if __name__ == "__main__":
    main()
