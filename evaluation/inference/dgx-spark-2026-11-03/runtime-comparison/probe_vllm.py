"""Run native JSON Schema SSE requests inside a private engine container."""

from __future__ import annotations

import importlib.metadata
import json
import sys
import time
import urllib.request


def main() -> None:
    cases = json.load(sys.stdin)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    endpoint = "http://127.0.0.1:8000"

    def active() -> float:
        with opener.open(endpoint + "/metrics", timeout=5) as response:
            metrics = response.read().decode()
        counters = [
            float(line.split()[-1])
            for line in metrics.splitlines()
            if line.startswith(
                ("vllm:num_requests_running{", "vllm:num_requests_waiting{")
            )
        ]
        assert len(counters) >= 2
        return sum(counters)

    for case in cases:
        assert active() == 0, "Another request is active"
        payload = {
            **case["payload"],
            "stream_options": {"include_usage": True},
            "return_token_ids": True,
        }
        token_request = urllib.request.Request(
            endpoint + "/tokenize",
            headers={"Content-Type": "application/json"},
            data=json.dumps(
                {"model": case["model"], "messages": payload["messages"]}
            ).encode(),
        )
        with opener.open(token_request, timeout=30) as response:
            tokenized = json.load(response)
        result = {
            "id": case["id"],
            "prompt_token_ids": tokenized["tokens"],
            "versions": {
                name: importlib.metadata.version(name)
                for name in ("vllm", "xgrammar", "llguidance", "transformers", "torch")
            },
            "active_before": 0,
        }
        started = time.monotonic()
        text, finish, usage, is_done, first = "", None, None, False, None
        output_tokens, stream_prompt = [], None
        try:
            request = urllib.request.Request(
                endpoint + "/v1/chat/completions",
                data=json.dumps(payload).encode(),
                headers={"Content-Type": "application/json"},
            )
            with opener.open(request, timeout=240) as response:
                for line in response:
                    if time.monotonic() - started > 240:
                        raise TimeoutError("Absolute generation deadline")
                    if not line.startswith(b"data:"):
                        continue
                    raw = line[5:].strip()
                    if raw == b"[DONE]":
                        is_done = True
                        break
                    item = json.loads(raw)
                    if item.get("prompt_token_ids") is not None:
                        stream_prompt = item["prompt_token_ids"]
                    if item.get("usage"):
                        usage = item["usage"]
                    for choice in item.get("choices", []):
                        part = choice.get("delta", {}).get("content") or ""
                        if part and first is None:
                            first = time.monotonic() - started
                        text += part
                        output_tokens += choice.get("token_ids") or []
                        finish = choice.get("finish_reason") or finish
        except Exception as error:
            result["error"] = type(error).__name__
            if hasattr(error, "read"):
                result["error_body"] = error.read().decode()[:3000]
        if stream_prompt is not None:
            assert stream_prompt == tokenized["tokens"], (
                "Tokenize and chat prompts differ"
            )
        for _ in range(50):
            remaining = active()
            if remaining == 0:
                break
            time.sleep(0.1)
        result.update(
            text=text,
            finish=finish,
            usage=usage,
            done=is_done,
            seconds=round(time.monotonic() - started, 3),
            first_delta_seconds=first,
            output_token_ids=output_tokens,
            stream_prompt_matches=stream_prompt == tokenized["tokens"],
            active_after=remaining,
        )
        print(json.dumps(result, ensure_ascii=False), flush=True)
        assert remaining == 0


if __name__ == "__main__":
    main()
