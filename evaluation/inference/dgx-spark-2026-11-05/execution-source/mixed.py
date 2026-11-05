"""Compare admission policies with all twelve synthetic jobs arriving together."""

from __future__ import annotations

import concurrent.futures
import copy
import fcntl
import json
from pathlib import Path
import statistics
import subprocess
import threading
import time
import urllib.request

from run import NAMES, ROOT, healthy, idle, inspect, save, snapshot, telemetry


def request(payload: dict, endpoint: str, arrival: float, admitted: float) -> dict:
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    payload = copy.deepcopy(payload)
    payload.update(stream=True, stream_options={"include_usage": True})
    row = {
        "arrival": arrival,
        "admitted": admitted,
        "admission_wait_seconds": admitted - arrival,
        "usage": {},
        "text": "",
        "done": False,
        "ttft_from_arrival": None,
    }
    try:
        req = urllib.request.Request(
            endpoint + "/v1/chat/completions",
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
        )
        with opener.open(req, timeout=600) as response:
            for line in response:
                if not line.startswith(b"data:"):
                    continue
                value = line[5:].strip()
                if value == b"[DONE]":
                    row["done"] = True
                    break
                value = json.loads(value)
                row["usage"] = value.get("usage") or row["usage"]
                for choice in value.get("choices", []):
                    text = choice.get("delta", {}).get("content") or ""
                    if text and row["ttft_from_arrival"] is None:
                        row["ttft_from_arrival"] = time.perf_counter() - arrival
                    row["text"] += text
                    row["finish"] = choice.get("finish_reason") or row.get("finish")
    except Exception as error:
        row["error"] = type(error).__name__
    row["latency_from_arrival"] = time.perf_counter() - arrival
    row["service_seconds"] = time.perf_counter() - admitted
    return row


def main() -> None:
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    directory = ROOT / "06-shared-gpu-scheduling"
    save(directory / "before.json", snapshot())
    endpoints = {}
    payloads = {}
    for key, name in zip(["4b", "15-4b", "27b"], NAMES[:3]):
        healthy(name)
        idle(name)
        networks = inspect(name)["NetworkSettings"]["Networks"]
        addresses = [n["IPAddress"] for n in networks.values() if n["IPAddress"]]
        assert len(addresses) == 1
        endpoints[key] = "http://" + addresses[0] + ":8000"
        for line in (
            (ROOT / "01-batching" / key / "baseline/results.jsonl")
            .read_text()
            .splitlines()
        ):
            record = json.loads(line)
            if record["event"] == "input" and record["group"] == "medium-c1":
                payloads[key] = record["settings"]["payload"]
                break
    save(
        directory / "plan.json",
        {
            "modes": ["parallel12", "global4", "global8", "model_groups"],
            "jobs_per_model": 4,
            "warmup_waves": 1,
            "measured_waves": 3,
            "payloads": payloads,
            "queue_time_included": True,
            "endpoints": endpoints,
        },
    )
    finish = threading.Event()
    current = {"mode": "starting", "wave": -1}

    def observe() -> None:
        with (ROOT / "07-host-health/telemetry-mixed.jsonl").open("x") as out:
            while not finish.is_set():
                out.write(json.dumps({**telemetry(), **current}) + "\n")
                out.flush()
                finish.wait(5)

    watcher = threading.Thread(target=observe)
    watcher.start()
    try:
        with (directory / "results.jsonl").open("x") as output:
            for wave in range(-1, 3):
                # Rotate policy order between waves to reduce thermal/order bias.
                modes = ["parallel12", "global4", "global8", "model_groups"]
                modes = modes[wave % 4 :] + modes[: wave % 4]
                for mode in modes:
                    current.update(mode=mode, wave=wave)
                    before = {name: idle(name) for name in NAMES[:3]}
                    jobs = [
                        (key, client)
                        for client in range(4)
                        for key in ["4b", "15-4b", "27b"]
                    ]
                    arrival = time.perf_counter()

                    def perform(job: tuple[str, int]) -> dict:
                        key, client = job
                        payload = copy.deepcopy(payloads[key])
                        payload["cache_salt"] = f"mixed:{mode}:{wave}:{key}:{client}"
                        return {
                            "model": key,
                            "client": client,
                            "mode": mode,
                            "wave": wave,
                            **request(
                                payload, endpoints[key], arrival, time.perf_counter()
                            ),
                        }

                    results = []
                    if mode == "model_groups":
                        for key in ["4b", "15-4b", "27b"]:
                            with concurrent.futures.ThreadPoolExecutor(4) as pool:
                                results += list(
                                    pool.map(
                                        perform, [job for job in jobs if job[0] == key]
                                    )
                                )
                    else:
                        count = {"parallel12": 12, "global4": 4, "global8": 8}[mode]
                        with concurrent.futures.ThreadPoolExecutor(count) as pool:
                            results = list(pool.map(perform, jobs))
                    seconds = time.perf_counter() - arrival
                    after = {name: idle(name) for name in NAMES[:3]}
                    valid = len(results) == 12 and all(
                        r["done"]
                        and not r.get("error")
                        and r["usage"].get("completion_tokens") == 128
                        for r in results
                    )
                    entry = {
                        "mode": mode,
                        "wave": wave,
                        "unix": time.time(),
                        "seconds": seconds,
                        "valid": valid,
                        "tokens": sum(
                            r["usage"].get("completion_tokens", 0) for r in results
                        ),
                        "requests": results,
                        "metrics_before": before,
                        "metrics_after": after,
                    }
                    output.write(json.dumps(entry, ensure_ascii=False) + "\n")
                    output.flush()
                    print(
                        json.dumps(
                            {
                                "mode": mode,
                                "wave": wave,
                                "seconds": seconds,
                                "valid": valid,
                            }
                        ),
                        flush=True,
                    )
                    if not valid:
                        raise RuntimeError("Mixed wave failed")
    finally:
        finish.set()
        watcher.join(timeout=20)
        save(directory / "after.json", snapshot())
    rows = [
        json.loads(line)
        for line in (directory / "results.jsonl").read_text().splitlines()
        if json.loads(line)["wave"] >= 0
    ]
    summary = []
    for mode in ["parallel12", "global4", "global8", "model_groups"]:
        waves = [r for r in rows if r["mode"] == mode]
        item = {
            "mode": mode,
            "waves": len(waves),
            "all_valid": all(w["valid"] for w in waves),
            "wave_seconds": statistics.median(w["seconds"] for w in waves),
            "aggregate_tps": statistics.median(
                w["tokens"] / w["seconds"] for w in waves
            ),
            "models": {},
        }
        for key in payloads:
            requests = [r for w in waves for r in w["requests"] if r["model"] == key]
            item["models"][key] = {
                field: statistics.median(r[field] for r in requests)
                for field in [
                    "latency_from_arrival",
                    "ttft_from_arrival",
                    "admission_wait_seconds",
                    "service_seconds",
                ]
            }
        summary.append(item)
    save(directory / "summary.json", summary)


if __name__ == "__main__":
    subprocess.run(["python3", str(ROOT / "cache_pressure.py")], check=True)
    subprocess.run(["python3", str(ROOT / "prefix.py")], check=True)
    subprocess.run(
        ["python3", str(ROOT / "check_prefix_format.py"), "--corrected"], check=True
    )
    main()
    subprocess.run(["python3", str(ROOT / "final_check.py")], check=True)
