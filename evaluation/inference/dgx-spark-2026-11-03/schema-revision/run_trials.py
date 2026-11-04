"""Run frozen synthetic cases against the existing engine without restarting it."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

DIRECTORY = Path(__file__).resolve().parent
sys.path.insert(0, str(DIRECTORY.parent / "runtime-comparison"))
import run_remote_comparison as lifecycle  # noqa: E402

ENGINE = "doglyad-dgx-vllm_medgemma_4b-1"
OTHERS = [
    "doglyad-dgx-vllm_medgemma_15_4b-1",
    "doglyad-dgx-vllm_medgemma_27b-1",
    "doglyad-dgx-backend_inference-1",
]


def snapshot() -> dict:
    result = {}
    for name in [ENGINE, *OTHERS]:
        value = lifecycle._inspect(name)
        result[name] = {
            "id": value["Id"],
            "image": value["Image"],
            "cmd": value["Config"]["Cmd"],
            "started_at": value["State"]["StartedAt"],
            "running": value["State"]["Running"],
        }
    return result


def activity() -> dict:
    result = {}
    code = "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/metrics',timeout=5).read().decode())"
    for name in OTHERS[:2]:
        metrics = subprocess.check_output(
            ["docker", "exec", name, "python3", "-c", code], text=True
        )
        result[name] = [
            line
            for line in metrics.splitlines()
            if line.startswith(
                ("vllm:request_success_total{", "vllm:generation_tokens_total{")
            )
        ]
    return result


def main() -> None:
    before = snapshot()
    assert all(x["running"] for x in before.values())
    for name in [ENGINE, *OTHERS[:2]]:
        lifecycle._idle(name)
    counters = activity()
    (DIRECTORY / "runtime-before.json").write_text(json.dumps(before, indent=2) + "\n")
    try:
        for variant in ("baseline", "prompt-only", "bounded", "working"):
            cases = json.loads((DIRECTORY / f"{variant}-cases.json").read_text())
            print(
                json.dumps(
                    {"event": "starting", "variant": variant, "count": len(cases)}
                ),
                flush=True,
            )
            settings = {
                "engine": "vllm",
                "cases": cases,
                "quality": True,
                "performance": False,
                "concurrencies": [1],
            }
            with (DIRECTORY / f"{variant}-results.jsonl").open("x") as destination:
                subprocess.run(
                    [
                        "docker",
                        "exec",
                        "-i",
                        ENGINE,
                        "python3",
                        "-c",
                        (DIRECTORY / "probe_engine.py").read_text(),
                    ],
                    input=json.dumps(settings),
                    text=True,
                    stdout=destination,
                    check=True,
                    timeout=3600,
                )
            print(json.dumps({"event": "finished", "variant": variant}), flush=True)
    finally:
        for name in [ENGINE, *OTHERS[:2]]:
            lifecycle._health(name, 30)
            lifecycle._idle(name)
        after = snapshot()
        (DIRECTORY / "runtime-after.json").write_text(
            json.dumps(after, indent=2) + "\n"
        )
        assert before == after, "Runtime changed during experiment"
        after_counters = activity()
        (DIRECTORY / "other-engine-activity.json").write_text(
            json.dumps(
                {
                    "before": counters,
                    "after": after_counters,
                    "unchanged": counters == after_counters,
                },
                indent=2,
            )
            + "\n"
        )
        assert counters == after_counters, "Other models received traffic"
        print(
            json.dumps({"event": "runtime_verified", "no_containers_restarted": True}),
            flush=True,
        )


if __name__ == "__main__":
    main()
