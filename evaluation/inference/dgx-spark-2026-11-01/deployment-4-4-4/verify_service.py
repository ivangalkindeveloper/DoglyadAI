"""Exercise deployed routes and limits inside the backend image, without HTTP auth bypass."""

import asyncio
import hashlib
import json
import time

import httpx
from app.core.create_app import create_app
from app.model.generation_request import GenerationRequest
from app.service.vllm_service import VLLMService


async def main():
    app = create_app()
    variables = app.state.variables
    config = app.state.server_config
    assert config.generation.max_concurrent_requests == 4
    assert config.generation.max_waiting_requests == 1
    assert config.vllm.operation_timeout_seconds == 120
    assert set(variables.model_endpoints) == {
        "google/medgemma-4b-it",
        "google/medgemma-1.5-4b-it",
        "google/medgemma-27b-it",
    }
    schema = {
        "type": "object",
        "properties": {
            k: {"type": "string"} for k in ["caseId", "description", "conclusion"]
        },
        "required": ["caseId", "description", "conclusion"],
        "additionalProperties": False,
    }
    result = {
        "boundary": "Isolated VLLMService in the live backend container, with its real environment and server config; HTTP App Check checked separately",
        "configuration_directory": str(variables.configuration_directory),
        "generation_config": config.generation.model_dump(),
        "endpoints": variables.model_endpoints,
        "waves": [],
    }
    async with httpx.AsyncClient(trust_env=False) as client:
        service = VLLMService(client, variables, config)
        for wave in range(2):
            gate = asyncio.Event()
            stopped = asyncio.Event()
            peaks = {model: 0 for model in variables.model_endpoints}
            metrics_errors = []

            async def monitor():
                while not stopped.is_set():
                    for model, url in variables.model_endpoints.items():
                        try:
                            response = await client.get(url + "/metrics", timeout=5)
                            response.raise_for_status()
                            values = [
                                float(line.rsplit(" ", 1)[1])
                                for line in response.text.splitlines()
                                if line.startswith("vllm:num_requests_running{")
                            ]
                            peaks[model] = max(peaks[model], sum(values))
                        except Exception as error:
                            metrics_errors.append(type(error).__name__)
                    await asyncio.sleep(0.5)

            async def request(model, index):
                identifier = f"deploy444-{wave}-{index}-{model.rsplit('/', 1)[1]}"
                await gate.wait()
                start = time.perf_counter()
                row = {"model": model, "index": index, "is_success": False}
                try:
                    content = await service.generate(
                        GenerationRequest(
                            modelId=model,
                            temperature=0,
                            maxTokens=256,
                            structuredOutput=json.dumps(schema),
                            prompt=f"Синтетический тест, не данные пациента. caseId: {identifier}. "
                            "Печень обычных размеров, структура однородная. Желчный пузырь без конкрементов. "
                            "Почки без расширения чашечно-лоханочной системы. Свободной жидкости нет. "
                            "Верни JSON. Точно перенеси caseId. description: три предложения по наблюдениям. "
                            "conclusion: одно предложение.",
                        )
                    )
                    value = json.loads(content)
                    assert set(value) == set(schema["required"])
                    assert all(isinstance(v, str) for v in value.values())
                    assert value["caseId"] == identifier
                    row.update(
                        is_success=True,
                        output_sha256=hashlib.sha256(content.encode()).hexdigest(),
                    )
                except Exception as error:
                    row["error_type"] = type(error).__name__
                row["seconds"] = time.perf_counter() - start
                return row

            monitor_task = asyncio.create_task(monitor())
            tasks = [
                asyncio.create_task(request(model, index))
                for model in variables.model_endpoints
                for index in range(4)
            ]
            started = time.perf_counter()
            gate.set()
            samples = await asyncio.gather(*tasks)
            elapsed = time.perf_counter() - started
            stopped.set()
            await monitor_task
            result["waves"].append(
                {
                    "wave": wave,
                    "seconds": elapsed,
                    "samples": samples,
                    "peak_running": peaks,
                    "metrics_errors": metrics_errors,
                }
            )
            print(
                json.dumps(
                    {
                        "wave": wave,
                        "success": sum(s["is_success"] for s in samples),
                        "requests": len(samples),
                        "seconds": elapsed,
                    }
                ),
                flush=True,
            )
            if not all(s["is_success"] for s in samples):
                break
    print("RESULT_JSON=" + json.dumps(result), flush=True)
    assert all(s["is_success"] for w in result["waves"] for s in w["samples"])
    assert len(result["waves"]) == 2


if __name__ == "__main__":
    asyncio.run(main())
