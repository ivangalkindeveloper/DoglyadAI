"""Benchmark private engines with synthetic requests and retain raw SSE results."""

from __future__ import annotations

import concurrent.futures
import copy
import hashlib
import json
import sys
import threading
import time
import urllib.error
import urllib.request


def main() -> None:
    settings = json.load(sys.stdin)
    endpoint = settings.get("endpoint", "http://127.0.0.1:8000")
    engine = settings["engine"]

    def request(
        case: dict, phase: str, barrier: threading.Barrier | None = None
    ) -> dict:
        payload = copy.deepcopy(case["payload"])
        payload["stream"] = True
        payload["stream_options"] = {"include_usage": True}
        if engine == "vllm":
            payload["return_token_ids"] = True
        elif engine == "llama.cpp":
            payload["repeat_penalty"] = payload.pop("repetition_penalty", 1.0)
            payload["repeat_last_n"] = 16384
            payload["min_p"] = 0.0
            payload["cache_prompt"] = True
            payload["return_tokens"] = True
        elif engine == "sglang":
            # SGLang uses -1 for disabled top-k; vLLM/Transformers use 0.
            if payload.get("top_k") == 0:
                payload["top_k"] = -1
            payload["return_input_ids_in_sglext"] = True
            payload["return_output_ids_in_sglext"] = True
        result = {
            "id": case["id"],
            "kind": case["kind"],
            "phase": phase,
            "engine": engine,
        }
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        if engine == "llama.cpp" and phase == "quality" and case["kind"] != "vision":

            def post(path: str, value: dict) -> dict:
                req = urllib.request.Request(
                    endpoint + path,
                    data=json.dumps(value).encode(),
                    headers={"Content-Type": "application/json"},
                )
                with opener.open(req, timeout=15) as response:
                    return json.load(response)

            prompt = post("/apply-template", {"messages": payload["messages"]})[
                "prompt"
            ]
            tokens = post(
                "/tokenize",
                {"content": prompt, "add_special": True, "parse_special": True},
            )["tokens"]
            result["template_prompt_token_ids"] = tokens
            result["template_prompt_sha256"] = hashlib.sha256(
                prompt.encode()
            ).hexdigest()
        if barrier:
            barrier.wait(timeout=30)
        start = time.perf_counter()
        first = last = None
        text = ""
        finish = None
        usage = {}
        done = False
        prompt_ids = None
        output_ids = []
        try:
            req = urllib.request.Request(
                endpoint + "/v1/chat/completions",
                data=json.dumps(payload).encode(),
                headers={"Content-Type": "application/json"},
            )
            with opener.open(req, timeout=180) as response:
                for line in response:
                    elapsed = time.perf_counter() - start
                    if elapsed > 300:
                        raise TimeoutError("Absolute deadline")
                    if not line.startswith(b"data:"):
                        continue
                    raw = line[5:].strip()
                    if raw == b"[DONE]":
                        done = True
                        break
                    item = json.loads(raw)
                    if item.get("error"):
                        raise RuntimeError(str(item["error"]))
                    usage = item.get("usage") or usage
                    prompt_ids = item.get("prompt_token_ids", prompt_ids)
                    if item.get("sglext"):
                        prompt_ids = item["sglext"].get("input_ids", prompt_ids)
                        if item["sglext"].get("output_ids"):
                            output_ids = item["sglext"]["output_ids"][0]
                    for choice in item.get("choices", []):
                        part = choice.get("delta", {}).get("content") or ""
                        if part:
                            first = elapsed if first is None else first
                            last = elapsed
                        text += part
                        finish = choice.get("finish_reason") or finish
                        output_ids.extend(choice.get("token_ids") or [])
                        prompt_ids = choice.get("prompt_token_ids", prompt_ids)
        except Exception as error:
            result["error"] = type(error).__name__
            result["detail"] = (
                error.read().decode()[:2000]
                if isinstance(error, urllib.error.HTTPError)
                else str(error)[:2000]
            )
        seconds = time.perf_counter() - start
        count = usage.get("completion_tokens", 0)
        result.update(
            text=text,
            finish=finish,
            usage=usage,
            done=done,
            seconds=seconds,
            first_delta_seconds=first,
            last_delta_seconds=last,
            prompt_token_ids=prompt_ids,
            output_token_ids=output_ids,
            output_sha256=hashlib.sha256(text.encode()).hexdigest(),
            decode_tokens_per_second=(count - 1) / (seconds - first)
            if count > 1 and first is not None
            else None,
        )
        return result

    def emit(value: dict) -> None:
        print(json.dumps(value, ensure_ascii=False), flush=True)

    warm = copy.deepcopy(settings["cases"][0])
    warm["payload"]["max_tokens"] = 16
    result = request(warm, "warmup")
    emit(result)
    if result.get("error"):
        raise RuntimeError("Warmup failed")
    for case in settings["cases"]:
        emit(request(case, "quality"))
    perf = settings["performance"]
    for count in settings.get("concurrencies", [1, 4]):
        for wave in range(-1, settings.get("repetitions", 5)):
            barrier = threading.Barrier(count)
            start = time.perf_counter()
            with concurrent.futures.ThreadPoolExecutor(count) as pool:
                rows = list(
                    pool.map(
                        lambda _: request(
                            perf, "speed_warmup" if wave < 0 else "speed", barrier
                        ),
                        range(count),
                    )
                )
            seconds = time.perf_counter() - start
            for index, row in enumerate(rows):
                row.update(concurrency=count, wave=wave, client=index)
                emit(row)
            emit(
                {
                    "event": "wave",
                    "engine": engine,
                    "concurrency": count,
                    "wave": wave,
                    "seconds": seconds,
                    "tokens": sum(
                        row["usage"].get("completion_tokens", 0) for row in rows
                    ),
                    "valid": all(
                        not row.get("error")
                        and row["done"]
                        and row["usage"].get("completion_tokens") == 256
                        for row in rows
                    ),
                }
            )


if __name__ == "__main__":
    main()
