"""Run a diagnostic variant on the existing engine; verify unchanged runtime."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

import run_trials as original

DIRECTORY = Path(__file__).resolve().parent


def main() -> None:
    variant = sys.argv[1]
    if variant != "unbounded-grammar":
        raise ValueError("Unknown diagnostic variant")
    before = original.snapshot()
    assert all(x["running"] for x in before.values())
    for name in [original.ENGINE, *original.OTHERS[:2]]:
        original.lifecycle._idle(name)
    counters = original.activity()
    (DIRECTORY / f"{variant}-runtime-before.json").write_text(json.dumps(before, indent=2) + "\n")
    try:
        cases = json.loads((DIRECTORY / f"{variant}-cases.json").read_text())
        print(json.dumps({"event": "starting", "variant": variant, "count": len(cases)}), flush=True)
        with (DIRECTORY / f"{variant}-results.jsonl").open("x") as destination:
            subprocess.run(
                ["docker", "exec", "-i", original.ENGINE, "python3", "-c", (DIRECTORY / "probe_engine.py").read_text()],
                input=json.dumps({"engine": "vllm", "cases": cases, "quality": True, "performance": False, "concurrencies": [1]}),
                text=True,
                stdout=destination,
                check=True,
                timeout=3600,
            )
        print(json.dumps({"event": "finished", "variant": variant}), flush=True)
    finally:
        for name in [original.ENGINE, *original.OTHERS[:2]]:
            original.lifecycle._health(name, 30)
            original.lifecycle._idle(name)
        after = original.snapshot()
        after_counters = original.activity()
        (DIRECTORY / f"{variant}-runtime-after.json").write_text(json.dumps(after, indent=2) + "\n")
        (DIRECTORY / f"{variant}-other-engine-activity.json").write_text(
            json.dumps({"before": counters, "after": after_counters, "unchanged": counters == after_counters}, indent=2) + "\n"
        )
        assert before == after, "Runtime changed during experiment"
        assert counters == after_counters, "Other models received traffic"
        print(json.dumps({"event": "runtime_verified", "no_containers_restarted": True}), flush=True)


if __name__ == "__main__":
    main()
