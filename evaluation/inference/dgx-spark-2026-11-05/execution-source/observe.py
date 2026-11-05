"""Observe engine counters without changing the running experiment process."""

from __future__ import annotations

import json
from pathlib import Path
import time

from run import NAMES, ROOT, TEMP, http


def main() -> None:
    output = ROOT / "07-host-health" / "engine-activity.jsonl"
    with output.open("x") as stream:
        while True:
            row = {"unix": time.time(), "engines": {}}
            for name in [*NAMES[:3], TEMP]:
                try:
                    lines = http(name, "/metrics").splitlines()
                    row["engines"][name] = [
                        line
                        for line in lines
                        if line.startswith("vllm:")
                        and any(
                            key in line.split("{", 1)[0]
                            for key in [
                                "num_requests_running",
                                "num_requests_waiting",
                                "request_success_total",
                                "generation_tokens_total",
                                "num_preemptions",
                                "kv_cache_usage",
                                "spec_decode",
                                "prefix_cache",
                            ]
                        )
                    ]
                except Exception:
                    row["engines"][name] = {"available": False}
            stream.write(json.dumps(row) + "\n")
            stream.flush()
            if (ROOT / "runtime-after.json").exists():
                break
            time.sleep(10)


if __name__ == "__main__":
    main()
