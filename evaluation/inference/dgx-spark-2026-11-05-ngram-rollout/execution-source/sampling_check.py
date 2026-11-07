"""Paired sampling seeds for the differing 1.5 4B validation case.

Only the 1.5 4B engine is temporarily recreated without N-gram, then restored.
The canonical profile stays unchanged. Other engines and the API stay running.
"""

import concurrent.futures
import copy
import fcntl
import json
from pathlib import Path
import subprocess
import threading
import time

from deploy import compose, start
from observe import NAMES, idle, inspect, save, snapshot, telemetry
from probe import request

ROOT = Path(__file__).resolve().parent
SERVICE = "vllm_medgemma_15_4b"
NAME = "doglyad-dgx-" + SERVICE + "-1"
SEEDS = [*range(15), 42]


def run_cases(profile):
    out = ROOT / "sampling-check" / profile
    out.mkdir(exist_ok=False)
    save(out / "runtime.json", snapshot())
    case = next(
        c
        for c in json.loads((ROOT / "cases-15-4b.json").read_text())
        if c["id"] == "conflict-sample-42"
    )
    addresses = [
        n["IPAddress"]
        for n in inspect(NAME)["NetworkSettings"]["Networks"].values()
        if n["IPAddress"]
    ]
    assert len(addresses) == 1
    endpoint = "http://" + addresses[0] + ":8000"
    with (out / "results.jsonl").open("x") as f:
        for at in range(0, len(SEEDS), 4):
            barrier = threading.Barrier(4)
            before = idle(NAME)

            def perform(seed):
                payload = copy.deepcopy(case["payload"])
                payload.update(seed=seed, cache_salt=f"sampling-check:{profile}:{seed}")
                return {"seed": seed, **request(payload, endpoint, barrier)}

            with concurrent.futures.ThreadPoolExecutor(4) as pool:
                rows = list(pool.map(perform, SEEDS[at : at + 4]))
            f.write(
                json.dumps(
                    {
                        "profile": profile,
                        "requests": rows,
                        "metrics_before": before,
                        "metrics_after": idle(NAME),
                        "host": telemetry(),
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )
            f.flush()
            assert all(
                r["done"] and r["finish"] == "stop" and not r.get("error") for r in rows
            )
            print(
                json.dumps(
                    {"profile": profile, "seeds": SEEDS[at : at + 4], "finished": True}
                ),
                flush=True,
            )


def main():
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    out = ROOT / "sampling-check"
    out.mkdir(exist_ok=False)
    before = snapshot()
    save(out / "before.json", before)
    command = list(before[NAME]["command"])
    at = command.index("--speculative-config")
    del command[at : at + 2]
    override = out / "baseline-override.json"
    save(override, {"services": {SERVICE: {"command": command}}})
    save(
        out / "plan.json",
        {
            "model": "google/medgemma-1.5-4b-it",
            "case": "conflict-sample-42",
            "seeds": SEEDS,
            "concurrency": 4,
            "temperature": 0.3,
            "order": ["ngram8", "baseline"],
            "other_engines_loaded_idle": True,
        },
    )
    for name in NAMES[:3]:
        idle(name)
    run_cases("ngram8")
    try:
        resolved = json.loads(
            subprocess.check_output(
                compose("-f", str(override), "config", "--format", "json"), text=True
            )
        )
        assert resolved["services"][SERVICE]["command"] == command
        process = subprocess.Popen(
            compose(
                "-f",
                str(override),
                "up",
                "-d",
                "--no-deps",
                "--pull",
                "never",
                "--wait",
                "--wait-timeout",
                "1200",
                SERVICE,
            )
        )
        with (out / "baseline-startup.jsonl").open("x") as f:
            deadline = time.monotonic() + 1230
            while process.poll() is None:
                row = telemetry()
                f.write(json.dumps(row) + "\n")
                f.flush()
                if (
                    row["memory_kib"]["MemAvailable"] < 4 * 1024 * 1024
                    or time.monotonic() > deadline
                ):
                    process.terminate()
                    process.wait(timeout=30)
                    raise RuntimeError("Startup memory/deadline guard")
                time.sleep(5)
        assert process.returncode == 0
        assert inspect(NAME)["Config"]["Cmd"] == command
        run_cases("baseline")
    finally:
        with (out / "restore-startup.jsonl").open("x") as f:
            start(SERVICE, f)
        after = snapshot()
        assert all(before[n] == after[n] for n in NAMES if n != NAME)
        assert all(
            before[NAME][key] == after[NAME][key]
            for key in ["image", "command", "restart_policy"]
        )
        save(out / "after.json", after)
        save(out / "status.json", {"status": "ngram8_restored", "unix": time.time()})


if __name__ == "__main__":
    main()
