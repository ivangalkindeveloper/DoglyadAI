from __future__ import annotations

import asyncio
import importlib.util
import json
import sys
from pathlib import Path

import httpx
import pytest

_directory = Path(__file__).parent
_fixture_spec = importlib.util.spec_from_file_location(
    "fixtures", _directory / "fixtures.py"
)
assert _fixture_spec and _fixture_spec.loader
fixtures = importlib.util.module_from_spec(_fixture_spec)
sys.modules["fixtures"] = fixtures
_fixture_spec.loader.exec_module(fixtures)
_spec = importlib.util.spec_from_file_location(
    "benchmark_matrix", _directory / "benchmark_matrix.py"
)
assert _spec and _spec.loader
matrix = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(matrix)


def test_payload_keeps_each_target_model() -> None:
    for model in [
        "google/medgemma-4b-it",
        "google/medgemma-1.5-4b-it",
        "google/medgemma-27b-it",
    ]:
        payload, expected = matrix._payload(model, "long", 1, "run")
        assert payload["model"] == model
        assert expected is None
        assert payload["max_tokens"] == 256
        assert payload["cache_salt"] == "run-1"


@pytest.mark.parametrize(
    "finish,tokens,is_success", [("length", 256, True), ("stop", 50, False)]
)
def test_stream_validation_and_gate(finish: str, tokens: int, is_success: bool) -> None:
    async def run() -> dict:
        def handler(request: httpx.Request) -> httpx.Response:
            data = [
                {
                    "choices": [
                        {"delta": {"content": "Synthetic"}, "finish_reason": finish}
                    ]
                },
                {
                    "choices": [],
                    "usage": {"prompt_tokens": 20, "completion_tokens": tokens},
                },
            ]
            return httpx.Response(
                200,
                text="".join("data: " + json.dumps(v) + "\n\n" for v in data)
                + "data: [DONE]\n\n",
            )

        async with httpx.AsyncClient(
            base_url="http://test", transport=httpx.MockTransport(handler)
        ) as client:
            gate = asyncio.Event()
            payload, expected = matrix._payload("model", "long", 1, "run")
            task = asyncio.create_task(
                matrix._request(client, "model", "long", 1, payload, expected, gate)
            )
            await asyncio.sleep(0)
            assert not task.done()
            gate.set()
            return await task

    result = asyncio.run(run())
    assert result["is_success"] is is_success
    assert "Synthetic" not in json.dumps(result)


def test_summary_uses_shared_wave_time_for_mixed_throughput() -> None:
    samples = [
        {
            "model": model,
            "is_success": True,
            "total_seconds": duration,
            "ttft_seconds": 1,
            "stream_decode_tokens_per_second": 10,
            "input_tokens": 100,
        }
        for model, duration in [("a", 10), ("b", 30)]
    ]
    rows = matrix._summary(
        [
            {
                "label": "mixed",
                "case": "long",
                "is_measured": True,
                "wall_seconds": 30,
                "output_tokens_per_second": 20,
                "samples": samples,
            }
        ]
    )
    assert [r["total_seconds_p50"] for r in rows] == [10, 30]
    assert all(r["group_wall_seconds_p50"] == 30 for r in rows)


def test_failed_requests_are_counted_without_latency_success_claim() -> None:
    rows = matrix._summary(
        [
            {
                "label": "mixed",
                "case": "long",
                "is_measured": True,
                "wall_seconds": 120,
                "output_tokens_per_second": 0,
                "samples": [{"model": "a", "is_success": False}],
            }
        ]
    )
    assert rows[0]["requests"] == 1 and rows[0]["successful"] == 0
    assert "total_seconds_p50" not in rows[0]


def test_absolute_deadline_is_recorded_as_failure(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    original_timeout = asyncio.timeout
    monkeypatch.setattr(
        matrix.asyncio, "timeout", lambda seconds: original_timeout(0.001)
    )

    async def run() -> dict:
        async def handler(request: httpx.Request) -> httpx.Response:
            await asyncio.sleep(0.02)
            return httpx.Response(200)

        async with httpx.AsyncClient(
            base_url="http://test", transport=httpx.MockTransport(handler)
        ) as client:
            gate = asyncio.Event()
            gate.set()
            payload, expected = matrix._payload("model", "long", 1, "run")
            return await matrix._request(
                client, "model", "long", 1, payload, expected, gate
            )

    result = asyncio.run(run())
    assert not result["is_success"]
    assert result["error_type"] == "TimeoutError"
