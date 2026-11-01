"""Validate measurement bookkeeping before using the GPU results."""

from __future__ import annotations

import asyncio
import importlib.util
import json
from pathlib import Path

import httpx
import pytest

_spec = importlib.util.spec_from_file_location(
    "dgx_benchmark", Path(__file__).with_name("benchmark.py")
)
assert _spec and _spec.loader
benchmark = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(benchmark)


def test_percentiles_are_explicit_interpolation() -> None:
    assert benchmark._percentile([10, 20, 30, 40, 50], 0.5) == 30
    assert benchmark._percentile([10, 20, 30, 40, 50], 0.95) == 48
    assert benchmark._percentile([12], 0.95) == 12


@pytest.mark.parametrize(
    "status,tokens,cached,is_success",
    [
        (200, 256, 0, True),
        (200, 12, 0, False),
        (200, 256, 64, False),
        (503, 0, 0, False),
    ],
)
def test_success_requires_complete_uncached_generation(
    status: int, tokens: int, cached: int, is_success: bool
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        sent = json.loads(request.content)
        assert sent["cache_salt"].startswith("unique-")
        events = [
            {"choices": [{"delta": {"content": "synthetic"}}]},
            {"choices": [{"delta": {"content": " text"}, "finish_reason": "length"}]},
            {
                "choices": [],
                "usage": {
                    "prompt_tokens": 10,
                    "completion_tokens": tokens,
                    "prompt_tokens_details": {"cached_tokens": cached},
                },
            },
        ]
        data = (
            "".join("data: " + json.dumps(e) + "\n\n" for e in events)
            + "data: [DONE]\n\n"
        )
        return httpx.Response(status, text=data)

    async def run() -> dict:
        async with httpx.AsyncClient(
            base_url="http://test", transport=httpx.MockTransport(handler)
        ) as client:
            return await benchmark._request(client, "short", 1, "unique")

    result = asyncio.run(run())
    assert result["is_success"] is is_success
    assert "synthetic text" not in json.dumps(result)


def test_structured_fixture_has_distinct_case_identity() -> None:
    first, expected_first = benchmark._structured_payload(1)
    second, expected_second = benchmark._structured_payload(2)
    assert expected_first["caseId"] != expected_second["caseId"]
    assert expected_first["caseId"] in first["messages"][0]["content"][0]["text"]
    assert expected_second["liverSizeMm"] != expected_first["liverSizeMm"]
    assert (
        second["response_format"]["json_schema"]["schema"]["additionalProperties"]
        is False
    )


@pytest.mark.parametrize("is_matching", [True, False])
def test_structured_result_cannot_cross_request_identity(is_matching: bool) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        text = json.dumps(
            {
                "caseId": "synthetic-1" if is_matching else "synthetic-2",
                "liverSizeMm": 131,
                "hasFreeFluid": False,
                "description": "synthetic",
                "conclusion": "synthetic",
            }
        )
        events = [
            {"choices": [{"delta": {"content": text}, "finish_reason": "stop"}]},
            {"choices": [], "usage": {"prompt_tokens": 10, "completion_tokens": 50}},
        ]
        return httpx.Response(
            200,
            text="".join("data: " + json.dumps(e) + "\n\n" for e in events)
            + "data: [DONE]\n\n",
        )

    async def run() -> dict:
        async with httpx.AsyncClient(
            base_url="http://test", transport=httpx.MockTransport(handler)
        ) as client:
            return await benchmark._request(client, "json", 1, "unique")

    assert asyncio.run(run())["is_success"] is is_matching


def test_summary_counts_time_after_last_visible_token(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = importlib.util.spec_from_file_location(
        "dgx_summarize", Path(__file__).with_name("summarize.py")
    )
    assert spec and spec.loader
    summarizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(summarizer)
    raw = {
        "finished_at": "test",
        "batches": [
            {
                "case": "short",
                "concurrency": 1,
                "is_measured": True,
                "samples": [
                    {
                        "case": "short",
                        "is_success": True,
                        "input_tokens": 10,
                        "output_tokens": 20,
                        "total_seconds": 2,
                        "ttft_seconds": 0.1,
                        "decode_tokens_per_second": 95,
                    }
                ],
            }
        ],
        "summaries": [
            {
                "case": "short",
                "concurrency": 1,
                "requests": 1,
                "decode_tokens_per_second_p50": 95,
            }
        ],
    }
    path = tmp_path / "eager-1.json"
    path.write_text(json.dumps(raw))
    (tmp_path / "conditions.json").write_text('{"variants": []}')
    monkeypatch.setattr("sys.argv", ["summarize.py", "--directory", str(tmp_path)])
    summarizer.main()
    derived = json.loads((tmp_path / "summary.json").read_text())
    assert (
        derived["variants"]["eager-1"]["summaries"][0][
            "stream_decode_tokens_per_second_p50"
        ]
        == 10
    )
    assert json.loads(path.read_text()) == raw
