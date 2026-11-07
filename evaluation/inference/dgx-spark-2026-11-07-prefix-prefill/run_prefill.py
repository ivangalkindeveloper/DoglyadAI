"""Measure current eight-slot/N-gram engines on fixed-token and report loads."""

from __future__ import annotations

import concurrent.futures
import copy
import json
from pathlib import Path
import threading
import time
from uuid import uuid4

from observe import NAMES, idle, inspect, save, snapshot, telemetry
from probe import request

ROOT = Path(__file__).resolve().parent
MODELS = ("4b", "15-4b", "27b")


def run(budget: int, directory: Path) -> None:
    directory.mkdir(exist_ok=False)
    technical = json.loads((ROOT / "prefill-cases.json").read_text())
    cases = {c["id"]: c for c in json.loads((ROOT / "cases.json").read_text())}
    endpoints = {}
    for model, name in zip(MODELS, NAMES[:3]):
        info = inspect(name)
        ips = [
            n["IPAddress"]
            for n in info["NetworkSettings"]["Networks"].values()
            if n["IPAddress"]
        ]
        assert len(ips) == 1
        endpoints[model] = "http://" + ips[0] + ":8000"
    namespace = "prefill-study-" + uuid4().hex
    waves = [
        ("warmup", 1, "technical"),
        ("technical4-1", 4, "technical"),
        ("technical8-1", 8, "technical"),
        ("technical8-2", 8, "technical"),
        ("technical4-2", 4, "technical"),
        ("report8", 8, "report"),
    ]
    save(
        directory / "plan.json",
        {
            "budget": budget,
            "waves": waves,
            "namespace": namespace,
            "all_three_models_concurrent": True,
            "engine_benchmark_not_authenticated_api": True,
        },
    )
    save(directory / "runtime-before.json", snapshot())
    finish, abort = threading.Event(), threading.Event()
    current = {"wave": "starting"}

    def watch() -> None:
        with (directory / "telemetry.jsonl").open("x") as output:
            while not finish.is_set():
                row = {**telemetry(), **current}
                output.write(json.dumps(row) + "\n")
                output.flush()
                if row["memory_kib"]["MemAvailable"] < 6 * 1024**2:
                    abort.set()
                finish.wait(5)

    watcher = threading.Thread(target=watch)
    watcher.start()
    try:
        with (directory / "results.jsonl").open("x") as output:
            for wave, count, kind in waves:
                assert not abort.is_set(), "Available RAM below experiment reserve"
                current["wave"] = wave
                before = {name: idle(name) for name in NAMES[:3]}
                jobs = [(model, client) for client in range(count) for model in MODELS]
                barrier = threading.Barrier(len(jobs))

                def perform(job: tuple) -> dict:
                    model, client = job
                    case_id = f"{model}:ru-photo0-template0:baseline:{client % 2}"
                    payload = copy.deepcopy(
                        technical[model]
                        if kind == "technical"
                        else cases[case_id]["payload"]
                    )
                    payload["cache_salt"] = f"{namespace}:{wave}:{model}:{client}"
                    return {
                        "model": model,
                        "client": client,
                        "case_id": case_id if kind == "report" else "technical-8k-128",
                        **request(payload, endpoints[model], barrier),
                    }

                started = time.perf_counter()
                with concurrent.futures.ThreadPoolExecutor(len(jobs)) as pool:
                    rows = list(pool.map(perform, jobs))
                seconds = time.perf_counter() - started
                after = {name: idle(name) for name in NAMES[:3]}
                record = {
                    "wave": wave,
                    "kind": kind,
                    "concurrency_per_model": count,
                    "seconds": seconds,
                    "requests": rows,
                    "metrics_before": before,
                    "metrics_after": after,
                }
                output.write(json.dumps(record, ensure_ascii=False) + "\n")
                output.flush()
                complete = all(
                    r["done"]
                    and not r.get("error")
                    and (
                        r["usage"].get("completion_tokens") == 128
                        if kind == "technical"
                        else r["finish"] == "stop"
                    )
                    for r in rows
                )
                print(
                    json.dumps(
                        {
                            "budget": budget,
                            "wave": wave,
                            "requests": len(rows),
                            "seconds": seconds,
                            "complete": complete,
                            "over120": sum(r["seconds"] > 120 for r in rows),
                        }
                    ),
                    flush=True,
                )
                assert all(r["done"] and not r.get("error") for r in rows), (
                    "Transport failed; evidence retained"
                )
    finally:
        finish.set()
        watcher.join(timeout=30)
        save(directory / "runtime-after.json", snapshot())
