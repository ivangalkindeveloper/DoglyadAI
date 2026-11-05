"""Measure synthetic streaming requests; run inside an isolated engine container."""

from __future__ import annotations

import concurrent.futures
import copy
import hashlib
import json
import statistics
import sys
import threading
import time
import urllib.error
import urllib.request


def emit(value: dict) -> None:
    print(json.dumps(value, ensure_ascii=False), flush=True)


def fetch(path: str) -> str:
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open("http://127.0.0.1:8000" + path, timeout=15) as response:
        return response.read().decode()


def sized_payload(payload: dict, target: int) -> dict:
    """Use the actual server tokenizer; retain the complete payload as evidence."""
    payload = copy.deepcopy(payload)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    phrase = "Синтетическое наблюдение: контуры ровные, структура однородная, размеры записаны в миллиметрах. "
    suffix = "\nПеречисли числа от 1 до 1000 словами по-русски. Каждое число на новой строке."
    low, high = 0, target
    while low + 1 < high:
        middle = (low + high) // 2
        messages = [{"role": "user", "content": phrase * middle + suffix}]
        req = urllib.request.Request(
            "http://127.0.0.1:8000/tokenize",
            data=json.dumps({"model": payload["model"], "messages": messages}).encode(),
            headers={"Content-Type": "application/json"},
        )
        with opener.open(req, timeout=30) as response:
            count = json.load(response)["count"]
        if count <= target:
            low = middle
        else:
            high = middle
    payload["messages"] = [{"role": "user", "content": phrase * low + suffix}]
    return payload


def request(payload: dict, barrier: threading.Barrier | None = None) -> dict:
    payload = copy.deepcopy(payload)
    payload.update(
        stream=True, stream_options={"include_usage": True}, return_token_ids=True
    )
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    if barrier:
        barrier.wait(timeout=30)
    start = time.perf_counter()
    row = {"text": "", "done": False, "usage": {}, "finish": None}
    deltas = []
    delta_token_counts = []
    ids = []
    try:
        req = urllib.request.Request(
            "http://127.0.0.1:8000/v1/chat/completions",
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
        )
        with opener.open(req, timeout=600) as response:
            for line in response:
                elapsed = time.perf_counter() - start
                if elapsed > 600:
                    raise TimeoutError("Absolute deadline")
                if not line.startswith(b"data:"):
                    continue
                value = line[5:].strip()
                if value == b"[DONE]":
                    row["done"] = True
                    break
                item = json.loads(value)
                if item.get("error"):
                    raise RuntimeError(str(item["error"]))
                row["usage"] = item.get("usage") or row["usage"]
                if item.get("prompt_token_ids") is not None:
                    row["prompt_token_ids"] = item["prompt_token_ids"]
                for choice in item.get("choices", []):
                    part = choice.get("delta", {}).get("content") or ""
                    if part:
                        deltas.append(elapsed)
                        delta_token_counts.append(len(choice.get("token_ids") or []))
                    row["text"] += part
                    row["finish"] = choice.get("finish_reason") or row["finish"]
                    ids.extend(choice.get("token_ids") or [])
                    if choice.get("prompt_token_ids") is not None:
                        row["prompt_token_ids"] = choice["prompt_token_ids"]
    except Exception as error:
        row["error"] = type(error).__name__
        row["detail"] = (
            error.read().decode()[:3000]
            if isinstance(error, urllib.error.HTTPError)
            else str(error)
        )
    row["seconds"] = time.perf_counter() - start
    row["ttft"] = deltas[0] if deltas else None
    row["delta_times"] = deltas
    row["delta_token_counts"] = delta_token_counts
    row["output_token_ids"] = ids
    row["output_sha256"] = hashlib.sha256(row["text"].encode()).hexdigest()
    tokens = row["usage"].get("completion_tokens", 0)
    row["output_tps"] = tokens / row["seconds"]
    row["decode_tps"] = (
        (tokens - delta_token_counts[0]) / (deltas[-1] - deltas[0])
        if tokens > 1 and len(deltas) > 1 and delta_token_counts[0]
        else None
    )
    gaps = [b - a for a, b in zip(deltas, deltas[1:])]
    row["median_delta_gap"] = statistics.median(gaps) if gaps else None
    row["maximum_delta_gap"] = max(gaps, default=None)
    return row


def main() -> None:
    settings = json.load(sys.stdin)
    sized = {}
    for group in settings["groups"]:
        common = {
            "study": group["study"],
            "group": group["id"],
            "profile": settings["profile"],
            "model_key": settings["model_key"],
        }
        if group.get("target_tokens"):
            target = group["target_tokens"]
            if target not in sized:
                sized[target] = sized_payload(group["payload"], target)
            messages = sized[target]["messages"]
            group["payload"]["messages"] = messages
        emit({**common, "event": "input", "settings": group})
        emit({**common, "event": "metrics_before", "metrics": fetch("/metrics")})
        for wave in range(
            -1 if group.get("warmup", True) else 0, group.get("repetitions", 3)
        ):
            count = group.get("concurrency", 1)
            barrier = threading.Barrier(count)
            payloads = []
            for client in range(count):
                payload = copy.deepcopy(group["payload"])
                salt = (
                    group.get("shared_salt")
                    or f"{settings['profile']}:{group['id']}:{wave}:{client}"
                )
                payload["cache_salt"] = salt
                if group.get("vary_suffix"):
                    payload["messages"][-1]["content"] += (
                        f"\nНомер синтетического запроса: {wave + 10}-{client}."
                    )
                payloads.append(payload)
            start = time.perf_counter()
            with concurrent.futures.ThreadPoolExecutor(count) as pool:
                futures = [
                    pool.submit(request, payload, barrier) for payload in payloads
                ]
                rows = [future.result() for future in futures]
            seconds = time.perf_counter() - start
            for client, row in enumerate(rows):
                emit(
                    {
                        **common,
                        "event": "request",
                        "wave": wave,
                        "client": client,
                        "concurrency": count,
                        **row,
                    }
                )
            valid = all(row["done"] and not row.get("error") for row in rows)
            if group.get("fixed_tokens"):
                valid = valid and all(
                    row["usage"].get("completion_tokens") == group["fixed_tokens"]
                    for row in rows
                )
            emit(
                {
                    **common,
                    "event": "wave",
                    "wave": wave,
                    "concurrency": count,
                    "seconds": seconds,
                    "tokens": sum(
                        row["usage"].get("completion_tokens", 0) for row in rows
                    ),
                    "valid": valid,
                }
            )
            if not valid:
                # Retain the failure, avoid repeating a rejected/unsafe test.
                break
        emit({**common, "event": "metrics_after", "metrics": fetch("/metrics")})


if __name__ == "__main__":
    main()
