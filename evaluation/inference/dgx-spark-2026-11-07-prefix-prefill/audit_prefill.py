"""Recompute the archived prefill measurements without changing their evidence."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import statistics

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT.with_name("dgx-spark-2026-11-05")


def main() -> None:
    expected = json.loads((SOURCE / "02-prefill-budget/summary.json").read_text())
    summaries, hashes = [], {}
    for item in expected:
        path = (
            SOURCE
            / "02-prefill-budget"
            / item["model"]
            / item["profile"]
            / "results.jsonl"
        )
        hashes[str(path.relative_to(ROOT.parent))] = hashlib.sha256(
            path.read_bytes()
        ).hexdigest()
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        measured = [r for r in rows if r["event"] == "request" and r["wave"] >= 0]
        assert len(measured) == 12
        assert all(
            r["done"]
            and r["finish"] == "length"
            and r["usage"]["completion_tokens"] == 128
            and not r.get("error")
            for r in measured
        )
        result = {
            "model": item["model"],
            "budget": 2048
            if item["profile"] == "baseline"
            else int(item["profile"].removeprefix("prefill")),
            "requests": len(measured),
            "ttft_seconds": statistics.median(r["ttft"] for r in measured),
            "latency_seconds": statistics.median(r["seconds"] for r in measured),
            "maximum_delta_gap_seconds": max(r["maximum_delta_gap"] for r in measured),
        }
        for key in ("ttft_seconds", "latency_seconds", "maximum_delta_gap_seconds"):
            assert abs(result[key] - item[key]) < 1e-9
        summaries.append(result)
    document = {
        "source_date": "2026-11-05",
        "audit_date": "2026-11-07",
        "new_gpu_measurements": False,
        "verified_groups": len(summaries),
        "verified_measured_requests": sum(row["requests"] for row in summaries),
        "conditions": {
            "concurrency": 4,
            "prompt_tokens_approximate": 8000,
            "output_tokens": 128,
            "prefix_cache": "isolated per request",
            "speculative_decoding": False,
        },
        "limitation": "Current profile uses 8 slots and N-gram 8; archived measurements do not test that combination or full medical reports.",
        "unavailable": {
            "model": "27b",
            "budget": 8192,
            "reason": "Startup requires 8.76 GiB KV cache; allocated 8 GiB",
            "source": "../dgx-spark-2026-11-05/runs/27b-prefill8192/container.log",
        },
        "summary": summaries,
        "source_sha256": hashes,
    }
    (ROOT / "prefill-audit.json").write_text(json.dumps(document, indent=2) + "\n")
    print(
        json.dumps(
            {
                "verified_groups": len(summaries),
                "verified_measured_requests": document["verified_measured_requests"],
                "summary_matches_original": True,
            }
        )
    )


if __name__ == "__main__":
    main()
