"""Synthetic, host-local measurements. Never save generated text or credentials."""
from __future__ import annotations

import argparse
import asyncio
import base64
import hashlib
import importlib.metadata
import io
import json
import math
import statistics
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

import httpx

MODEL = "google/medgemma-4b-it"
REVISION = "290cda5eeccbee130f987c4ad74a59ae6f196408"
RECORD = (
    "Печень обычных размеров, контуры ровные, структура однородная. "
    "Желчный пузырь без видимых конкрементов, стенка не утолщена. "
    "Поджелудочная железа обычных размеров. Селезёнка не увеличена. "
    "Почки расположены обычно, чашечно-лоханочная система не расширена. "
    "Свободная жидкость не определяется. "
)
INTRO = "Синтетические данные для проверки скорости модели. Это не данные пациента. "
TASK = "\nСоставь подробное описание всех перечисленных наблюдений на русском языке. Не добавляй отсутствующие измерения. "
CASES = {
    "short": INTRO + RECORD + TASK,
    "long": INTRO + "\n".join(f"Наблюдение {i+1}. {RECORD}" for i in range(16)) + TASK,
}


def _image() -> str:
    from PIL import Image, ImageDraw

    image = Image.new("RGB", (256, 256), (40, 40, 40))
    draw = ImageDraw.Draw(image)
    for i in range(0, 256, 32):
        draw.line((i, 0, i, 255), fill=(120, 120, 120), width=2)
        draw.line((0, i, 255, i), fill=(120, 120, 120), width=2)
    draw.ellipse((70, 70, 185, 185), outline="white", width=4)
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=85)
    return base64.b64encode(buffer.getvalue()).decode()


def _structured_payload(index: int, images: int = 0) -> tuple[dict, dict]:
    expected = {"caseId": f"synthetic-{index}", "liverSizeMm": 130 + index % 20, "hasFreeFluid": False}
    schema = {
        "type": "object",
        "properties": {
            "caseId": {"type": "string"},
            "liverSizeMm": {"type": "integer"},
            "hasFreeFluid": {"type": "boolean"},
            "description": {"type": "string"},
            "conclusion": {"type": "string"},
        },
        "required": ["caseId", "liverSizeMm", "hasFreeFluid", "description", "conclusion"],
        "additionalProperties": False,
    }
    text = (
        INTRO + f"Идентификатор случая: {expected['caseId']}. Размер печени {expected['liverSizeMm']} мм. "
        + RECORD + "Верни JSON по схеме. Точно перенеси идентификатор и измерение. "
        "В description дай описание в двух предложениях. В conclusion дай одно предложение. "
        "Если приложено изображение, это искусственная тестовая сетка, не УЗИ. Не делай по ней клинических выводов."
    )
    content = [{"type": "text", "text": text}]
    if images:
        image = _image()
        content.extend({"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + image}} for _ in range(images))
    return {
        "model": MODEL,
        "messages": [{"role": "user", "content": content}],
        "temperature": 0,
        "seed": 0,
        "max_tokens": 384,
        "response_format": {"type": "json_schema", "json_schema": {"name": "synthetic_report", "schema": schema}},
    }, expected


async def _request(client: httpx.AsyncClient, case: str, index: int, run_id: str) -> dict:
    expected = None
    if case in CASES:
        payload = {"model": MODEL, "messages": [{"role": "user", "content": CASES[case]}],
                   "max_tokens": 256, "ignore_eos": True, "temperature": 0, "seed": 0}
    else:
        payload, expected = _structured_payload(index, {"json": 0, "image_json": 1, "six_images_json": 6}[case])
    payload.update(stream=True, stream_options={"include_usage": True}, cache_salt=f"{run_id}-{case}-{index}")
    first = last = None
    usage = None
    finish = None
    pieces = []
    start = time.perf_counter()
    result = {"case": case, "index": index, "is_success": False}
    try:
        async with client.stream("POST", "/v1/chat/completions", json=payload) as response:
            result["http_status"] = response.status_code
            if response.status_code != 200:
                await response.aread()
                raise RuntimeError(f"HTTP {response.status_code}")
            async for line in response.aiter_lines():
                if not line.startswith("data: "):
                    continue
                if line[6:] == "[DONE]":
                    break
                event = json.loads(line[6:])
                if event.get("error"):
                    raise RuntimeError("Stream error")
                if event.get("usage"):
                    usage = event["usage"]
                for choice in event.get("choices", []):
                    content = choice.get("delta", {}).get("content")
                    if content:
                        now = time.perf_counter()
                        first = now if first is None else first
                        last = now
                        pieces.append(content)
                    finish = choice.get("finish_reason") or finish
        end = time.perf_counter()
        if not usage or first is None or last is None:
            raise RuntimeError("Missing usage or streamed content")
        text = "".join(pieces)
        result.update(input_tokens=usage["prompt_tokens"], output_tokens=usage["completion_tokens"],
                      cached_tokens=(usage.get("prompt_tokens_details") or {}).get("cached_tokens"),
                      ttft_seconds=first-start, total_seconds=end-start, finish_reason=finish,
                      decode_tokens_per_second=(usage["completion_tokens"]-1)/(last-first) if last > first else None,
                      output_sha256=hashlib.sha256(text.encode()).hexdigest())
        if result["cached_tokens"] not in (0, None):
            raise RuntimeError("Unexpected prefix cache reuse")
        if expected is None:
            if usage["completion_tokens"] != 256 or finish != "length":
                raise RuntimeError("Unexpected output length")
        else:
            value = json.loads(text)
            from jsonschema import validate

            validate(value, payload["response_format"]["json_schema"]["schema"])
            if any(value[key] != wanted for key, wanted in expected.items()):
                raise RuntimeError("Synthetic case field mismatch")
            if finish != "stop":
                raise RuntimeError("Structured response was truncated")
            result["is_schema_valid"] = True
            result["is_case_match"] = True
        result["is_success"] = True
    except Exception as error:
        # Error types and fixed messages only: never include a response payload.
        result["error_type"] = type(error).__name__
        result["total_seconds"] = time.perf_counter()-start
    return result


def _percentile(values: list[float], q: float) -> float:
    ordered = sorted(values)
    position = (len(ordered)-1)*q
    low, high = math.floor(position), math.ceil(position)
    return ordered[low] + (ordered[high]-ordered[low])*(position-low)


async def _run(args: argparse.Namespace) -> None:
    output = Path(args.output)
    run_id = str(uuid.uuid4())
    result = {"variant": args.variant, "model": MODEL, "revision": REVISION,
              "started_at": datetime.now(timezone.utc).isoformat(), "run_id": run_id,
              "method": {"transport": "host-local streaming HTTP to private vLLM", "fixed_output_tokens": 256,
                         "cache": "unique cache_salt for every request", "temperature": 0, "seed": 0,
                         "is_synthetic": True, "is_clinical_quality_evaluation": False,
                         "p95_method": "linear interpolation; small sample, descriptive only"},
              "versions": {n: importlib.metadata.version(n) for n in ["vllm", "torch", "transformers", "xgrammar", "httpx"]},
              "batches": [], "summaries": []}
    output.parent.mkdir(parents=True, exist_ok=True)
    counter = 0
    plan = [("short", 1, 5, 2), ("long", 1, 5, 2), ("json", 1, 3, 1), ("image_json", 1, 3, 1), ("six_images_json", 1, 1, 0)]
    if args.is_load:
        plan += [("long", c, 3, 1) for c in [2, 4, 8]]
        plan += [("image_json", c, 2, 1) for c in [2, 4, 8]]
    elif args.is_queue_baseline:
        plan += [("long", 4, 1, 0)]
    async with httpx.AsyncClient(base_url=args.url, timeout=120, trust_env=False,
                                limits=httpx.Limits(max_connections=20, max_keepalive_connections=20)) as client:
        (await client.get("/health")).raise_for_status()
        for case, concurrency, runs, warmups in plan:
            for wave in range(warmups+runs):
                started = time.perf_counter()
                rows = await asyncio.gather(*[_request(client, case, counter+i, run_id) for i in range(concurrency)])
                counter += concurrency
                elapsed = time.perf_counter()-started
                batch = {"case": case, "concurrency": concurrency, "wave": wave, "is_measured": wave >= warmups,
                         "wall_seconds": elapsed,
                         "aggregate_output_tokens_per_second": sum(r.get("output_tokens", 0) for r in rows if r["is_success"])/elapsed,
                         "samples": rows}
                result["batches"].append(batch)
                output.write_text(json.dumps(result, ensure_ascii=False, indent=2))
                print(json.dumps({"variant": args.variant, "case": case, "concurrency": concurrency,
                                  "wave": wave, "is_measured": wave >= warmups, "wall_seconds": round(elapsed, 3),
                                  "success": sum(r["is_success"] for r in rows), "requests": concurrency}), flush=True)
                if not all(r["is_success"] for r in rows):
                    raise RuntimeError("A benchmark request failed; partial results saved")
            batches = [b for b in result["batches"] if b["case"] == case and b["concurrency"] == concurrency and b["is_measured"]]
            rows = [r for b in batches for r in b["samples"]]
            summary = {"case": case, "concurrency": concurrency, "requests": len(rows),
                       "aggregate_output_tokens_per_second": statistics.median(b["aggregate_output_tokens_per_second"] for b in batches)}
            for metric in ["ttft_seconds", "total_seconds", "decode_tokens_per_second"]:
                values = [r[metric] for r in rows if r.get(metric) is not None]
                summary[metric+"_p50"] = statistics.median(values)
                summary[metric+"_p95"] = _percentile(values, .95)
            result["summaries"].append(summary)
            output.write_text(json.dumps(result, ensure_ascii=False, indent=2))
    result["finished_at"] = datetime.now(timezone.utc).isoformat()
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8000")
    parser.add_argument("--variant", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--is-load", action="store_true")
    parser.add_argument("--is-queue-baseline", action="store_true")
    asyncio.run(_run(parser.parse_args()))


if __name__ == "__main__":
    main()
