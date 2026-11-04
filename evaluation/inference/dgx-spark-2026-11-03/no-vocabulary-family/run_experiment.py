"""Run a named manifest on the existing 4B engine and verify runtime isolation."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

DIRECTORY = Path(__file__).resolve().parent
sys.path.insert(0, str(DIRECTORY.parent / "schema-revision"))
import run_trials as original  # noqa: E402


def main() -> None:
    manifest = Path(sys.argv[1])
    variants = json.loads(manifest.read_text())
    prefix = manifest.stem
    if len(sys.argv) > 2:
        engines = [original.ENGINE, *original.OTHERS[:2]]
        backend = original.OTHERS[-1]
        original.ENGINE = sys.argv[2]
        assert original.ENGINE in engines
        original.OTHERS = [name for name in engines if name != original.ENGINE] + [backend]
    before = original.snapshot()
    assert all(value["running"] for value in before.values())
    for name in [original.ENGINE, *original.OTHERS[:2]]:
        original.lifecycle._idle(name)
    counters = original.activity()
    (DIRECTORY / f"{prefix}-runtime-before.json").write_text(json.dumps(before, indent=2) + "\n")
    try:
        for variant in variants:
            cases = json.loads((DIRECTORY / f"{variant}-cases.json").read_text())
            print(json.dumps({"event": "starting", "variant": variant, "count": len(cases)}), flush=True)
            settings = {"engine": "vllm", "cases": cases, "quality": True, "performance": False, "concurrencies": [1]}
            with (DIRECTORY / f"{variant}-results.jsonl").open("x") as output:
                subprocess.run(
                    ["docker", "exec", "-i", original.ENGINE, "python3", "-c", (DIRECTORY / "probe_engine.py").read_text()],
                    input=json.dumps(settings), text=True, stdout=output, check=True, timeout=3600,
                )
            print(json.dumps({"event": "finished", "variant": variant}), flush=True)
    finally:
        for name in [original.ENGINE, *original.OTHERS[:2]]:
            original.lifecycle._health(name, 30)
            original.lifecycle._idle(name)
        after = original.snapshot()
        after_counters = original.activity()
        (DIRECTORY / f"{prefix}-runtime-after.json").write_text(json.dumps(after, indent=2) + "\n")
        (DIRECTORY / f"{prefix}-other-activity.json").write_text(json.dumps({"before": counters, "after": after_counters, "unchanged": counters == after_counters}, indent=2) + "\n")
        assert before == after
        assert counters == after_counters
        print(json.dumps({"event": "runtime_verified", "containers_unchanged": True}), flush=True)


if __name__ == "__main__":
    main()
