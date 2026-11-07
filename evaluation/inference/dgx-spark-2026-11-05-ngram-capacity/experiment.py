"""Compare full answers and a separate fixed-token KV pressure workload."""

import concurrent.futures
import copy
import json
from pathlib import Path
import threading
import time
import urllib.request

from observe import NAMES, idle, inspect, save, snapshot, telemetry
from probe import request

ROOT = Path(__file__).resolve().parent
KEYS = ["4b", "15-4b", "27b"]
MIXED = [
    "report-sample-42",
    "conflict-greedy-0",
    "dictation-greedy-0",
    "vision-2",
    "bladder-correction-sample-42",
    "bladder-en-sample-42",
    "conflict-sample-42",
    "vision-1",
]
WAVES = [
    ("warmup", 4, "report"),
    ("light1", 1, "report"),
    ("report4-1", 4, "report"),
    ("report4-2", 4, "report"),
    ("report8-1", 8, "report"),
    ("report8-2", 8, "report"),
    ("mixed8", 8, "mixed"),
    ("pressure4", 4, "pressure"),
    ("pressure8", 8, "pressure"),
]


def run(profile, directory):
    directory.mkdir(exist_ok=False)
    cases = {
        k: {c["id"]: c for c in json.loads((ROOT / f"cases-{k}.json").read_text())}
        for k in KEYS
    }
    pressure = json.loads((ROOT / "pressure-payload.json").read_text())
    endpoints = {}
    for key, name in zip(KEYS, NAMES[:3]):
        info = inspect(name)
        ips = [
            n["IPAddress"]
            for n in info["NetworkSettings"]["Networks"].values()
            if n["IPAddress"]
        ]
        assert len(ips) == 1
        endpoints[key] = "http://" + ips[0] + ":8000"
    save(
        directory / "plan.json",
        {
            "profile": profile,
            "waves": WAVES,
            "mixed_cases": MIXED,
            "engine_benchmark_not_authenticated_api": True,
            "baseline_c8_exceeds_current_api_admission": True,
            "pressure_not_application_report": True,
        },
    )
    save(directory / "runtime-before.json", snapshot())
    finish = threading.Event()
    current = {"wave": "starting"}
    abort = threading.Event()

    def watch():
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with (directory / "telemetry.jsonl").open("x") as f:
            while not finish.is_set():
                row = {**telemetry(), **current, "engines": {}}
                for key, url in endpoints.items():
                    try:
                        with opener.open(url + "/metrics", timeout=4) as response:
                            metrics = response.read().decode()
                        row["engines"][key] = [
                            line
                            for line in metrics.splitlines()
                            if line.startswith(
                                (
                                    "vllm:num_requests_running{",
                                    "vllm:num_requests_waiting{",
                                    "vllm:kv_cache_usage_perc{",
                                )
                            )
                        ]
                    except Exception as error:
                        row["engines"][key] = {"error": type(error).__name__}
                f.write(json.dumps(row) + "\n")
                f.flush()
                if row["memory_kib"]["MemAvailable"] < 6 * 1024**2:
                    abort.set()
                finish.wait(5)

    watcher = threading.Thread(target=watch)
    watcher.start()
    try:
        with (directory / "results.jsonl").open("x") as f:
            for wave, count, kind in WAVES:
                if abort.is_set():
                    raise RuntimeError("Available RAM below experiment reserve")
                current["wave"] = wave
                before = {name: idle(name) for name in NAMES[:3]}
                models = ["27b"] if kind == "pressure" else KEYS
                jobs = [(key, i) for i in range(count) for key in models]
                barrier = threading.Barrier(len(jobs))

                def perform(job):
                    key, client = job
                    case_id = MIXED[client] if kind == "mixed" else "report-greedy-0"
                    if kind == "pressure":
                        payload = copy.deepcopy(pressure)
                        case_id = "technical-pressure-15k-256"
                    else:
                        payload = copy.deepcopy(cases[key][case_id]["payload"])
                    payload["cache_salt"] = f"capacity:{profile}:{wave}:{key}:{client}"
                    return {
                        "model": key,
                        "client": client,
                        "case": case_id,
                        **request(payload, endpoints[key], barrier),
                    }

                started = time.perf_counter()
                with concurrent.futures.ThreadPoolExecutor(len(jobs)) as pool:
                    rows = list(pool.map(perform, jobs))
                seconds = time.perf_counter() - started
                after = {name: idle(name) for name in NAMES[:3]}
                row = {
                    "wave": wave,
                    "kind": kind,
                    "concurrency_per_model": count,
                    "unix": time.time(),
                    "seconds": seconds,
                    "requests": rows,
                    "metrics_before": before,
                    "metrics_after": after,
                }
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
                f.flush()
                valid = all(
                    r["done"]
                    and not r.get("error")
                    and (
                        r["usage"].get("completion_tokens") == 256
                        if kind == "pressure"
                        else r["finish"] == "stop"
                    )
                    for r in rows
                )
                print(
                    json.dumps(
                        {
                            "profile": profile,
                            "wave": wave,
                            "seconds": seconds,
                            "valid": valid,
                            "over120": sum(r["seconds"] > 120 for r in rows),
                        }
                    ),
                    flush=True,
                )
                if not valid:
                    raise RuntimeError("Incomplete benchmark answer; evidence retained")
    finally:
        finish.set()
        watcher.join(timeout=30)
        save(directory / "runtime-after.json", snapshot())
