from __future__ import annotations

import argparse
import json
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any


def request_case(case: dict[str, Any], model_id: str) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "model": model_id,
        "messages": [
            {"role": "system", "content": [{"type": "text", "text": case["systemPrompt"]}]},
            {"role": "user", "content": [{"type": "text", "text": case["prompt"]}]},
        ],
        "response_format": {
            "type": "json_schema",
            "json_schema": {"name": "structured_response", "schema": case["schema"]},
        },
        "temperature": 0,
        "max_tokens": 2048,
    }
    if model_id.startswith("Qwen/") or model_id.startswith("numind/NuExtract3"):
        payload["chat_template_kwargs"] = {"enable_thinking": False}
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    started = time.monotonic()
    error_message = ""
    for attempt in range(1, 4):
        try:
            request = urllib.request.Request(
                "http://vllm:8000/v1/chat/completions",
                data=data,
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(request, timeout=125) as response:
                body = json.load(response)
            return {
                "id": case["id"],
                "modelId": model_id,
                "status": "ok",
                "content": body["choices"][0]["message"]["content"],
                "finishReason": body["choices"][0].get("finish_reason"),
                "usage": body.get("usage"),
                "attempts": attempt,
                "elapsedSeconds": round(time.monotonic() - started, 3),
            }
        except (urllib.error.URLError, ValueError, KeyError, IndexError, TypeError) as error:
            error_message = f"{type(error).__name__}: {str(error)[:180]}"
            if isinstance(error, urllib.error.HTTPError) and 400 <= error.code < 500:
                break
            time.sleep(attempt)
    return {
        "id": case["id"],
        "modelId": model_id,
        "status": "request_error",
        "error": error_message,
        "attempts": attempt,
        "elapsedSeconds": round(time.monotonic() - started, 3),
    }


def run(cases_path: Path, results_path: Path, model_id: str, limit: int | None, workers: int) -> None:
    cases = [json.loads(line) for line in cases_path.read_text(encoding="utf-8").splitlines()]
    if limit is not None:
        cases = cases[:limit]
    results_path.parent.mkdir(parents=True, exist_ok=True)
    completed = (
        {row["id"] for line in results_path.read_text(encoding="utf-8").splitlines() if (row := json.loads(line))}
        if results_path.exists()
        else set()
    )
    pending = [case for case in cases if case["id"] not in completed]
    lock = threading.Lock()
    with ThreadPoolExecutor(max_workers=workers) as executor, results_path.open("a", encoding="utf-8") as output:
        futures = [executor.submit(request_case, case, model_id) for case in pending]
        for future in as_completed(futures):
            row = future.result()
            with lock:
                output.write(json.dumps(row, ensure_ascii=False) + "\n")
                output.flush()
            completed.add(row["id"])
            if len(completed) % 25 == 0 or len(completed) == len(cases):
                print(f"{model_id}: {len(completed)}/{len(cases)}", flush=True)
    if len(completed) != len(cases):
        raise RuntimeError(f"Incomplete run: {len(completed)}/{len(cases)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("cases", type=Path)
    parser.add_argument("results", type=Path)
    parser.add_argument("model_id")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--workers", type=int, default=2)
    args = parser.parse_args()
    run(args.cases, args.results, args.model_id, args.limit, args.workers)


if __name__ == "__main__":
    main()
