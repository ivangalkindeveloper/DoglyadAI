"""Measure private OpenAI-compatible SSE engines with frozen synthetic inputs."""

from __future__ import annotations

import concurrent.futures
import copy
import hashlib
import importlib.metadata
import json
import sys
import threading
import time
import urllib.error
import urllib.request


def main() -> None:
    settings = json.load(sys.stdin)
    endpoint = "http://127.0.0.1:8000"
    engine = settings["engine"]
    cases = settings["cases"]
    versions = {}
    for name in (
        "vllm",
        "sglang",
        "xgrammar",
        "transformers",
        "torch",
        "flashinfer-python",
    ):
        try:
            versions[name] = importlib.metadata.version(name)
        except importlib.metadata.PackageNotFoundError:
            pass
    print(json.dumps({"event": "versions", "versions": versions}), flush=True)

    def request(
        case: dict, phase: str, barrier: threading.Barrier | None = None
    ) -> dict:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        payload = copy.deepcopy(case["payload"])
        payload["stream_options"] = {"include_usage": True}
        if phase.startswith("quality"):
            if engine == "vllm":
                payload["return_token_ids"] = True
            else:
                payload["return_input_ids_in_sglext"] = True
                payload["return_output_ids_in_sglext"] = True
        result = {"id": case["id"], "phase": phase, "kind": case["kind"]}
        deadline_seconds = 600 if phase.startswith("quality") else 240
        if barrier:
            barrier.wait(timeout=30)
        started = time.perf_counter()
        first = None
        last = None
        text = ""
        usage = None
        finish = None
        done = False
        output_tokens = []
        engine_output_token_chunks = []
        prompt_tokens = None
        chunks = 0
        try:
            req = urllib.request.Request(
                endpoint + "/v1/chat/completions",
                data=json.dumps(payload).encode(),
                headers={"Content-Type": "application/json"},
            )
            with opener.open(req, timeout=deadline_seconds) as response:
                for line in response:
                    now = time.perf_counter()
                    if now - started > deadline_seconds:
                        raise TimeoutError("Absolute generation deadline")
                    if not line.startswith(b"data:"):
                        continue
                    raw = line[5:].strip()
                    if raw == b"[DONE]":
                        done = True
                        break
                    item = json.loads(raw)
                    if item.get("error"):
                        raise RuntimeError(str(item["error"]))
                    if item.get("usage"):
                        usage = item["usage"]
                    if item.get("prompt_token_ids") is not None:
                        prompt_tokens = item["prompt_token_ids"]
                    if (item.get("sglext") or {}).get("input_ids") is not None:
                        prompt_tokens = item["sglext"]["input_ids"]
                    if (item.get("sglext") or {}).get("output_ids") is not None:
                        engine_output_token_chunks.append(item["sglext"]["output_ids"])
                    for choice in item.get("choices", []):
                        part = choice.get("delta", {}).get("content") or ""
                        if part:
                            if first is None:
                                first = now - started
                            last = now - started
                            chunks += 1
                        text += part
                        finish = choice.get("finish_reason") or finish
                        output_tokens.extend(choice.get("token_ids") or [])
                        if choice.get("prompt_token_ids") is not None:
                            prompt_tokens = choice["prompt_token_ids"]
        except Exception as error:
            result["error"] = type(error).__name__
            if isinstance(error, urllib.error.HTTPError):
                result["error_body"] = error.read().decode()[:2000]
            else:
                result["error_detail"] = str(error)[:1000]
        elapsed = time.perf_counter() - started
        completion = (usage or {}).get("completion_tokens", 0)
        if engine == "sglang" and engine_output_token_chunks:
            # SGLang emits complete per-choice output IDs in the final usage chunk.
            output_tokens = engine_output_token_chunks[-1][0]
        if phase.startswith("quality") and "expected_prompt_token_ids" in case:
            result["prompt_tokens_match_reference"] = (
                prompt_tokens == case["expected_prompt_token_ids"]
            )
            if not result["prompt_tokens_match_reference"]:
                result["error"] = "PromptTokenMismatch"
        result.update(
            text=text,
            finish=finish,
            usage=usage,
            done=done,
            seconds=elapsed,
            first_delta_seconds=first,
            last_delta_seconds=last,
            content_chunks=chunks,
            output_token_ids=output_tokens,
            engine_output_token_chunks=engine_output_token_chunks,
            prompt_token_ids=prompt_tokens,
            output_sha256=hashlib.sha256(text.encode()).hexdigest(),
            output_tokens_per_second=completion / elapsed if completion else None,
            decode_tokens_per_second_approx=(completion - 1) / (elapsed - first)
            if completion > 1 and first is not None and elapsed > first
            else None,
        )
        return result

    # Compilation, grammar creation, and one actual decode are excluded from warm timings.
    warmup = copy.deepcopy(next(c for c in cases if c["id"] == "report-greedy-0"))
    warmup["payload"]["max_tokens"] = 16
    result = request(warmup, "quality_warmup")
    print(json.dumps(result, ensure_ascii=False), flush=True)
    if result.get("error"):
        raise RuntimeError("Warmup failed")
    for case in cases if settings.get("quality", True) else []:
        result = request(case, "quality")
        print(json.dumps(result, ensure_ascii=False), flush=True)
        if result.get("error"):
            raise RuntimeError("Quality request failed: " + case["id"])
    if not settings.get("performance", True):
        return
    if not settings.get("quality", True) and 4 in settings["concurrencies"]:
        # Full responses under real overlap, separate from the fixed-length speed test.
        selected = [
            c
            for c in cases
            if c["id"]
            in {
                "historical-greedy-0",
                "report-greedy-0",
                "conflict-greedy-0",
                "dictation-greedy-0",
            }
        ]
        assert len(selected) == 4
        barrier = threading.Barrier(5)
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            tasks = [
                pool.submit(request, c, "quality_parallel", barrier) for c in selected
            ]
            barrier.wait(timeout=30)
            for future in tasks:
                row = future.result(timeout=630)
                row["concurrency"] = 4
                print(json.dumps(row, ensure_ascii=False), flush=True)
    benchmark = copy.deepcopy(next(c for c in cases if c["id"] == "report-greedy-0"))
    # Equal decode budgets isolate speed from differences in generated report length.
    # These intentionally truncated samples do not assess report correctness.
    benchmark["payload"]["max_tokens"] = 256
    for concurrency in settings["concurrencies"]:
        for repeat in range(-1, settings.get("repetitions", 3)):
            phase = "performance_warmup" if repeat == -1 else "performance"
            barrier = threading.Barrier(concurrency + 1)
            with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as pool:
                tasks = [
                    pool.submit(request, benchmark, phase, barrier)
                    for _ in range(concurrency)
                ]
                wave_start = time.perf_counter()
                barrier.wait(timeout=30)
                rows = [future.result(timeout=270) for future in tasks]
                wall = time.perf_counter() - wave_start
            total_tokens = sum(
                (row.get("usage") or {}).get("completion_tokens", 0) for row in rows
            )
            for index, row in enumerate(rows):
                row.update(
                    concurrency=concurrency,
                    repetition=repeat,
                    request_index=index,
                    benchmark_output_limit=256,
                )
                print(json.dumps(row, ensure_ascii=False), flush=True)
            print(
                json.dumps(
                    {
                        "event": "wave",
                        "phase": phase,
                        "concurrency": concurrency,
                        "repetition": repeat,
                        "seconds": wall,
                        "completion_tokens": total_tokens,
                        "aggregate_tokens_per_second": total_tokens / wall,
                        "errors": sum(bool(row.get("error")) for row in rows),
                    }
                ),
                flush=True,
            )


if __name__ == "__main__":
    main()
