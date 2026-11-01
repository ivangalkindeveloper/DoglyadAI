"""Host-local mixed-model benchmark. Synthetic inputs; generated text is not stored."""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import statistics
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

import fixtures
import httpx
import jsonschema


def _payload(
    model: str, case: str, index: int, run_id: str, context: str | None = None
) -> tuple[dict, dict | None]:
    expected = None
    if case == "images":
        payload, expected = fixtures._structured_payload(
            index, images=6, is_distinct=True
        )
    else:
        payload = {
            "messages": [
                {
                    "role": "user",
                    "content": context if case == "context" else fixtures.CASES["long"],
                }
            ],
            "temperature": 0,
            "seed": 0,
            "max_tokens": 64 if case == "context" else 256,
            "ignore_eos": True,
        }
    payload.update(
        model=model,
        stream=True,
        stream_options={"include_usage": True},
        cache_salt=f"{run_id}-{index}",
    )
    return payload, expected


async def _request(
    client: httpx.AsyncClient,
    model: str,
    case: str,
    index: int,
    payload: dict,
    expected: dict | None,
    gate: asyncio.Event,
) -> dict:
    await gate.wait()
    started = time.perf_counter()
    result = {
        "model": model,
        "case": case,
        "index": index,
        "is_success": False,
        "started_monotonic": started,
    }
    first = usage = finish = None
    pieces = []
    try:
        # Match the service's total operation deadline, not just a per-chunk read timeout.
        async with asyncio.timeout(120):
            async with client.stream(
                "POST", "/v1/chat/completions", json=payload
            ) as response:
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
                    usage = event.get("usage") or usage
                    for choice in event.get("choices", []):
                        text = choice.get("delta", {}).get("content")
                        if text:
                            first = time.perf_counter() if first is None else first
                            pieces.append(text)
                        finish = choice.get("finish_reason") or finish
        ended = time.perf_counter()
        if not usage or first is None:
            raise RuntimeError("Missing stream metadata")
        text = "".join(pieces)
        result.update(
            input_tokens=usage["prompt_tokens"],
            output_tokens=usage["completion_tokens"],
            finish_reason=finish,
            total_seconds=ended - started,
            ttft_seconds=first - started,
            stream_decode_tokens_per_second=(usage["completion_tokens"] - 1)
            / (ended - first),
            cached_tokens=(usage.get("prompt_tokens_details") or {}).get(
                "cached_tokens"
            ),
            output_sha256=hashlib.sha256(text.encode()).hexdigest(),
        )
        if result["cached_tokens"] not in (None, 0):
            raise RuntimeError("Unexpected prefix cache reuse")
        if expected is None:
            if (
                usage["completion_tokens"] != payload["max_tokens"]
                or finish != "length"
            ):
                raise RuntimeError("Incomplete fixed-length output")
        else:
            value = json.loads(text)
            jsonschema.validate(
                value, payload["response_format"]["json_schema"]["schema"]
            )
            if any(value.get(k) != v for k, v in expected.items()):
                raise RuntimeError("Synthetic field mismatch")
            if finish != "stop":
                raise RuntimeError("Truncated JSON")
            result.update(is_schema_valid=True, is_case_match=True)
        result["is_success"] = True
    except Exception as error:
        result.update(
            error_type=type(error).__name__, total_seconds=time.perf_counter() - started
        )
        if type(error) is RuntimeError:
            result["error"] = str(
                error
            )  # Fixed internal messages; never server payloads.
    result["finished_monotonic"] = time.perf_counter()
    return result


async def _metrics(client: httpx.AsyncClient) -> dict:
    response = await client.get("/metrics")
    response.raise_for_status()
    counters = {}
    for line in response.text.splitlines():
        for name in [
            "num_requests_running",
            "num_requests_waiting",
            "num_preemptions_total",
        ]:
            if line.startswith(f"vllm:{name}{{"):
                counters[name] = counters.get(name, 0) + float(line.rsplit(" ", 1)[1])
    return counters


async def _context(client: httpx.AsyncClient, model: str) -> tuple[str, int]:
    low, high, best, count = 1, 240, "", 0
    while low <= high:
        repeat = (low + high) // 2
        text = (
            fixtures.INTRO
            + "\n".join(f"Наблюдение {i + 1}. {fixtures.RECORD}" for i in range(repeat))
            + fixtures.TASK
        )
        response = await client.post(
            "/tokenize",
            json={
                "model": model,
                "messages": [{"role": "user", "content": text}],
                "add_generation_prompt": True,
            },
        )
        response.raise_for_status()
        tokens = response.json()["count"]
        if tokens <= 15872:
            best, count, low = text, tokens, repeat + 1
        else:
            high = repeat - 1
    if not 15000 < count <= 15872:
        raise RuntimeError("Failed to prepare near-limit input")
    return best, count


def _summary(batches: list[dict]) -> list[dict]:
    rows = []
    groups = sorted({(b["label"], b["case"]) for b in batches if b["is_measured"]})
    for label, case in groups:
        group = [
            b
            for b in batches
            if b["is_measured"] and b["label"] == label and b["case"] == case
        ]
        models = sorted({r["model"] for b in group for r in b["samples"]})
        for model in models:
            samples = [r for b in group for r in b["samples"] if r["model"] == model]
            good = [r for r in samples if r["is_success"]]
            row = {
                "label": label,
                "case": case,
                "model": model,
                "requests": len(samples),
                "successful": len(good),
                "group_wall_seconds_p50": statistics.median(
                    b["wall_seconds"] for b in group
                ),
                "group_output_tokens_per_second_p50": statistics.median(
                    b["output_tokens_per_second"] for b in group
                ),
            }
            if good:
                for metric in [
                    "total_seconds",
                    "ttft_seconds",
                    "stream_decode_tokens_per_second",
                ]:
                    values = sorted(r[metric] for r in good)
                    pos = (len(values) - 1) * 0.95
                    lower = int(pos)
                    row[metric + "_p50"] = statistics.median(values)
                    row[metric + "_p95"] = values[lower] + (
                        values[min(lower + 1, len(values) - 1)] - values[lower]
                    ) * (pos - lower)
                row["input_tokens_min"] = min(r["input_tokens"] for r in good)
                row["input_tokens_max"] = max(r["input_tokens"] for r in good)
            rows.append(row)
    return rows


async def _run(args: argparse.Namespace) -> None:
    targets = json.loads(Path(args.targets).read_text())
    run_id = str(uuid.uuid4())
    result = {
        "stage": args.stage,
        "runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "fixtures_sha256": hashlib.sha256(
            Path(fixtures.__file__).read_bytes()
        ).hexdigest(),
        "run_id": run_id,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "targets": targets,
        "is_synthetic": True,
        "operation_timeout_seconds": 120,
        "method": "Synchronized waves; unique cache salt; BF16; fixed 256/64 token text; unique JPEG images; full-stream decode timing",
        "batches": [],
        "summaries": [],
    }
    clients = {
        t["model"]: httpx.AsyncClient(
            base_url=t["url"],
            trust_env=False,
            timeout=120,
            limits=httpx.Limits(max_connections=12, max_keepalive_connections=12),
        )
        for t in targets
    }
    contexts = {}
    try:
        for model, client in clients.items():
            (await client.get("/health")).raise_for_status()
            if args.stage == "candidate":
                contexts[model] = (await _context(client, model))[0]
        plan = []
        for t in targets:
            plan.append((t["key"] + "-single", "long", {t["model"]: 1}, 3, 1))
            if args.stage == "candidate":
                plan.append(
                    (
                        t["key"] + "-parallel",
                        "long",
                        {t["model"]: t["concurrency"]},
                        3,
                        1,
                    )
                )
                plan.append(
                    (
                        t["key"] + "-parallel",
                        "images",
                        {t["model"]: t["concurrency"]},
                        2,
                        1,
                    )
                )
        if args.stage == "candidate":
            combined = {t["model"]: t["concurrency"] for t in targets}
            plan += [
                ("mixed-4-4-2", "long", combined, 3, 1),
                ("mixed-4-4-2", "images", combined, 2, 1),
                ("mixed-4-4-2", "context", combined, 1, 1),
            ]
        index = 0
        for label, case, counts, runs, warmups in plan:
            for wave in range(runs + warmups):
                gate = asyncio.Event()
                prepared = []
                for model, count in counts.items():
                    for _ in range(count):
                        payload, expected = _payload(
                            model, case, index, run_id, contexts.get(model)
                        )
                        prepared.append((model, index, payload, expected))
                        index += 1
                before = {m: await _metrics(c) for m, c in clients.items()}
                if any(
                    v.get("num_requests_running", 0) or v.get("num_requests_waiting", 0)
                    for v in before.values()
                ):
                    raise RuntimeError("Unexpected active requests between waves")
                tasks = [
                    asyncio.create_task(_request(clients[m], m, case, i, p, e, gate))
                    for m, i, p, e in prepared
                ]
                started = time.perf_counter()
                gate.set()
                samples = await asyncio.gather(*tasks)
                elapsed = time.perf_counter() - started
                batch = {
                    "label": label,
                    "case": case,
                    "wave": wave,
                    "is_measured": wave >= warmups,
                    "counts": counts,
                    "wall_seconds": elapsed,
                    "samples": samples,
                    "output_tokens_per_second": sum(
                        r.get("output_tokens", 0) for r in samples if r["is_success"]
                    )
                    / elapsed,
                    "metrics_before": before,
                    "metrics_after": {m: await _metrics(c) for m, c in clients.items()},
                }
                result["batches"].append(batch)
                result["summaries"] = _summary(result["batches"])
                Path(args.output).write_text(json.dumps(result, indent=2))
                print(
                    json.dumps(
                        {
                            "stage": args.stage,
                            "label": label,
                            "case": case,
                            "wave": wave,
                            "is_measured": wave >= warmups,
                            "seconds": round(elapsed, 3),
                            "success": sum(r["is_success"] for r in samples),
                            "requests": len(samples),
                        }
                    ),
                    flush=True,
                )
                if not all(r["is_success"] for r in samples):
                    # A deadline/validation failure is an experimental result.
                    # Continue only after every engine is healthy and idle.
                    deadline = time.monotonic() + 30
                    while True:
                        for client in clients.values():
                            (await client.get("/health")).raise_for_status()
                        counters = [
                            await _metrics(client) for client in clients.values()
                        ]
                        if all(
                            not c.get("num_requests_running", 0)
                            and not c.get("num_requests_waiting", 0)
                            for c in counters
                        ):
                            break
                        if time.monotonic() > deadline:
                            raise RuntimeError(
                                "Engine did not drain after a failed wave"
                            )
                        await asyncio.sleep(1)
        result["is_all_successful"] = all(
            r["is_success"] for b in result["batches"] for r in b["samples"]
        )
        result["finished_at"] = datetime.now(timezone.utc).isoformat()
        Path(args.output).write_text(json.dumps(result, indent=2))
    finally:
        await asyncio.gather(*(c.aclose() for c in clients.values()))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", choices=["baseline", "candidate"], required=True)
    parser.add_argument("--targets", required=True)
    parser.add_argument("--output", required=True)
    asyncio.run(_run(parser.parse_args()))


if __name__ == "__main__":
    main()
