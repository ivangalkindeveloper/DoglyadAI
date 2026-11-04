"""Sequential tests on existing DGX engines with unchanged containers."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

DIRECTORY = Path(__file__).resolve().parent
sys.path.insert(0, str(DIRECTORY.parent / "schema-revision"))
import run_trials as original  # noqa: E402

ENGINES = {
    "medgemma-15-4b": "doglyad-dgx-vllm_medgemma_15_4b-1",
    "medgemma-27b": "doglyad-dgx-vllm_medgemma_27b-1",
}
ALL_ENGINES = [original.ENGINE, *original.OTHERS[:2]]


def activity(names: list[str]) -> dict:
    result = {}
    code = "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/metrics',timeout=5).read().decode())"
    for name in names:
        metrics = subprocess.check_output(["docker", "exec", name, "python3", "-c", code], text=True)
        result[name] = [
            line for line in metrics.splitlines()
            if line.startswith(("vllm:request_success_total{", "vllm:generation_tokens_total{"))
        ]
    return result


def main() -> None:
    initial = original.snapshot()
    assert all(value["running"] for value in initial.values())
    for name, engine in ENGINES.items():
        destination = DIRECTORY / name
        for running_engine in ALL_ENGINES:
            original.lifecycle._idle(running_engine)
        before = original.snapshot()
        others = [item for item in ALL_ENGINES if item != engine]
        counters = activity(others)
        (destination / "runtime-before.json").write_text(json.dumps(before, indent=2) + "\n")
        try:
            for variant in ("working", "unbounded-grammar"):
                cases = json.loads((destination / f"{variant}-cases.json").read_text())
                print(json.dumps({"event": "starting", "model": name, "variant": variant, "count": len(cases)}), flush=True)
                settings = {"engine": "vllm", "cases": cases, "quality": True, "performance": False, "concurrencies": [1]}
                with (destination / f"{variant}-results.jsonl").open("x") as output:
                    subprocess.run(
                        ["docker", "exec", "-i", engine, "python3", "-c", (DIRECTORY.parent / "schema-revision/probe_engine.py").read_text()],
                        input=json.dumps(settings), text=True, stdout=output, check=True, timeout=3600,
                    )
                print(json.dumps({"event": "finished", "model": name, "variant": variant}), flush=True)
        finally:
            for running_engine in ALL_ENGINES:
                original.lifecycle._health(running_engine, 30)
                original.lifecycle._idle(running_engine)
            after = original.snapshot()
            after_counters = activity(others)
            (destination / "runtime-after.json").write_text(json.dumps(after, indent=2) + "\n")
            (destination / "other-engine-activity.json").write_text(
                json.dumps({"before": counters, "after": after_counters, "unchanged": counters == after_counters}, indent=2) + "\n"
            )
            assert before == after, "Runtime changed during experiment"
            assert counters == after_counters, "Other models received traffic"
            print(json.dumps({"event": "runtime_verified", "model": name, "no_containers_restarted": True}), flush=True)
    assert original.snapshot() == initial
    print(json.dumps({"event": "all_finished", "containers_unchanged": True}), flush=True)


if __name__ == "__main__":
    main()
