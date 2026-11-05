"""Keep long contexts alive long enough to exercise the KV-cache budget."""

from __future__ import annotations

import copy
import fcntl
import json
from pathlib import Path
import subprocess
import threading
import time

from run import (
    NAMES,
    ROOT,
    TEMP,
    call,
    healthy,
    idle,
    inspect,
    run_probe,
    save,
    snapshot,
    stop_temp,
    telemetry,
)


def success_counts(value: dict) -> list[str]:
    return [
        line
        for line in value["metrics"].splitlines()
        if line.startswith("vllm:request_success_total{")
    ]


def main() -> None:
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    initial = snapshot()
    save(ROOT / "04-kv-cache/pressure-before.json", initial)
    plans = []
    original_plans = json.loads((ROOT / "plan.json").read_text())
    for index, key in enumerate(["4b", "15-4b", "27b"]):
        baseline = next(
            p
            for p in original_plans
            if p["model_key"] == key and p["profile"] == "baseline"
        )
        group = copy.deepcopy(
            next(g for g in baseline["groups"] if g["study"] == "04-kv-cache")
        )
        group.update(
            id="held-context-c8", repetitions=2, fixed_tokens=256 if index == 2 else 512
        )
        group["payload"]["max_tokens"] = group["fixed_tokens"]
        for label in ["pressure-default", "pressure-plus"]:
            plans.append(
                {
                    "model_index": index,
                    "model_key": key,
                    "model": baseline["model"],
                    "profile": label,
                    "groups": [copy.deepcopy(group)],
                    "kv_gib": (12 if index == 2 else 6)
                    if label.endswith("plus")
                    else (8 if index == 2 else 4),
                }
            )
    save(ROOT / "cache-pressure-plan.json", plans)
    stop = threading.Event()
    current = {"trial": "pressure-startup"}
    critical = []

    def observe() -> None:
        with (ROOT / "07-host-health/telemetry-cache-pressure.jsonl").open(
            "x"
        ) as stream:
            while not stop.is_set():
                try:
                    row = {**telemetry(), **current}
                    stream.write(json.dumps(row) + "\n")
                    stream.flush()
                    if row["memory_kib"]["MemAvailable"] < 4 * 1024**2:
                        critical.append(row)
                        subprocess.run(
                            ["docker", "stop", "-t", "5", TEMP],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                            timeout=30,
                        )
                except Exception as error:
                    stream.write(
                        json.dumps({"unix": time.time(), "error": type(error).__name__})
                        + "\n"
                    )
                    stream.flush()
                stop.wait(5)

    watcher = threading.Thread(target=observe)
    watcher.start()
    stopped = None
    directory = ROOT
    try:
        for plan in plans:
            if critical:
                raise RuntimeError("Memory safety threshold reached")
            name = NAMES[plan["model_index"]]
            if stopped and stopped != name:
                call(["docker", "start", stopped], timeout=60)
                healthy(stopped)
                stopped = None
            original = inspect(name)
            for candidate in NAMES[:3]:
                if candidate != stopped:
                    healthy(candidate)
                    idle(candidate)
            tag = plan["model_key"] + "-" + plan["profile"]
            directory = ROOT / "runs" / tag
            directory.mkdir(exist_ok=False)
            current["trial"] = tag
            before = {
                candidate: idle(candidate)
                for candidate in NAMES[:3]
                if candidate != name
            }
            if stopped != name:
                call(["docker", "stop", "-t", "30", name], timeout=60)
                stopped = name
            args = list(original["Config"]["Cmd"])
            args[args.index("--max-num-seqs") + 1] = "8"
            args[args.index("--kv-cache-memory-bytes") + 1] = str(
                plan["kv_gib"] * 1024**3
            )
            memory = "85g" if plan["model_index"] == 2 else "30g"
            command = [
                "docker",
                "run",
                "-d",
                "--name",
                TEMP,
                "--gpus",
                "all",
                "--network",
                "none",
                "--shm-size",
                "4g",
                "--memory",
                memory,
                "--memory-swap",
                memory,
                "--volumes-from",
                name + ":ro",
                "-e",
                "HF_HUB_OFFLINE=1",
                "-e",
                "TRANSFORMERS_OFFLINE=1",
                "-e",
                "HF_HUB_DISABLE_PROGRESS_BARS=1",
                original["Image"],
                *args,
            ]
            save(directory / "command.json", command)
            print(
                json.dumps(
                    {"event": "pressure_start", "trial": tag, "unix": time.time()}
                ),
                flush=True,
            )
            try:
                call(command, timeout=60)
                healthy(TEMP)
                run_probe(TEMP, plan, directory)
            except Exception as error:
                save(
                    directory / "failure.json",
                    {"error": type(error).__name__, "detail": str(error)},
                )
            finally:
                stop_temp(directory)
            after = {
                candidate: idle(candidate)
                for candidate in NAMES[:3]
                if candidate != name
            }
            save(directory / "activity.json", {"before": before, "after": after})
            for candidate in NAMES[:3]:
                if candidate != name:
                    # Request counters of idle engines must not change.
                    assert success_counts(before[candidate]) == success_counts(
                        after[candidate]
                    ), candidate
            print(
                json.dumps(
                    {"event": "pressure_end", "trial": tag, "unix": time.time()}
                ),
                flush=True,
            )
    finally:
        stop_temp(directory)
        if stopped:
            call(["docker", "start", stopped], timeout=60)
            healthy(stopped)
        stop.set()
        watcher.join(timeout=20)
        after = snapshot()
        save(ROOT / "04-kv-cache/pressure-after.json", after)
        assert all(
            initial[name][key] == after[name][key]
            for name in NAMES
            for key in ["id", "image", "command", "restart_policy"]
        )
        assert all(after[name]["running"] for name in NAMES)


if __name__ == "__main__":
    main()
