"""Validate measurement bookkeeping before using the GPU results."""
from __future__ import annotations

import asyncio
import importlib.util
import json
from pathlib import Path

import httpx
import pytest

_spec = importlib.util.spec_from_file_location("dgx_benchmark", Path(__file__).with_name("benchmark.py"))
assert _spec and _spec.loader
benchmark = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(benchmark)


def test_percentiles_are_explicit_interpolation() -> None:
    assert benchmark._percentile([10, 20, 30, 40, 50], .5) == 30
    assert benchmark._percentile([10, 20, 30, 40, 50], .95) == 48
    assert benchmark._percentile([12], .95) == 12


@pytest.mark.parametrize("status,tokens,cached,is_success", [(200, 256, 0, True), (200, 12, 0, False), (200, 256, 64, False), (503, 0, 0, False)])
def test_success_requires_complete_uncached_generation(status: int, tokens: int, cached: int, is_success: bool) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        sent = json.loads(request.content)
        assert sent["cache_salt"].startswith("unique-")
        events = [{"choices": [{"delta": {"content": "synthetic"}}]},
                  {"choices": [{"delta": {"content": " text"}, "finish_reason": "length"}]},
                  {"choices": [], "usage": {"prompt_tokens": 10, "completion_tokens": tokens, "prompt_tokens_details": {"cached_tokens": cached}}}]
        data = "".join("data: "+json.dumps(e)+"\n\n" for e in events)+"data: [DONE]\n\n"
        return httpx.Response(status, text=data)

    async def run() -> dict:
        async with httpx.AsyncClient(base_url="http://test", transport=httpx.MockTransport(handler)) as client:
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
    assert second["response_format"]["json_schema"]["schema"]["additionalProperties"] is False
