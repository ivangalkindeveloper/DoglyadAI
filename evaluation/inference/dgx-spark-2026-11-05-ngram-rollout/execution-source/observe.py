"""Run isolated vLLM parameter comparisons on DGX and restore original containers."""

from __future__ import annotations

import fcntl
import json
from pathlib import Path
import signal
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parent
NAMES = [
    "doglyad-dgx-vllm_medgemma_4b-1",
    "doglyad-dgx-vllm_medgemma_15_4b-1",
    "doglyad-dgx-vllm_medgemma_27b-1",
    "doglyad-dgx-backend_inference-1",
]
TEMP = "doglyad-tuning-20261105"


def call(args: list[str], **kwargs) -> str:
    return subprocess.check_output(
        args, text=True, timeout=kwargs.pop("timeout", 30), **kwargs
    ).strip()


def inspect(name: str) -> dict:
    return json.loads(call(["docker", "inspect", name]))[0]


def save(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def event(name: str, **values) -> None:
    print(json.dumps({"event": name, "unix": time.time(), **values}), flush=True)


def http(name: str, path: str) -> str:
    code = (
        "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000"
        + path
        + "',timeout=5).read().decode())"
    )
    return call(
        ["docker", "exec", name, "python3", "-c", code],
        stderr=subprocess.DEVNULL,
        timeout=15,
    )


def idle(name: str) -> dict:
    metrics = http(name, "/metrics")
    active = [
        float(line.split()[-1])
        for line in metrics.splitlines()
        if line.startswith(("vllm:num_requests_running{", "vllm:num_requests_waiting{"))
    ]
    assert len(active) >= 2 and sum(active) == 0, f"Busy: {name}"
    return {"metrics": metrics}


def healthy(name: str, timeout: int = 1200) -> None:
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if not inspect(name)["State"]["Running"]:
            raise RuntimeError(f"Engine exited: {name}")
        try:
            http(name, "/health")
            return
        except subprocess.SubprocessError:
            time.sleep(5)
    raise TimeoutError(f"Startup: {name}")


def snapshot() -> dict:
    data = {}
    for name in NAMES:
        d = inspect(name)
        data[name] = {
            "id": d["Id"],
            "image": d["Image"],
            "command": d["Config"]["Cmd"],
            "restart_policy": d["HostConfig"]["RestartPolicy"],
            "started": d["State"]["StartedAt"],
            "running": d["State"]["Running"],
            "health": d["State"].get("Health", {}).get("Status"),
        }
    return data


def telemetry() -> dict:
    mem = {
        line.split(":")[0]: int(line.split()[1])
        for line in Path("/proc/meminfo").read_text().splitlines()
        if line.startswith(
            (
                "MemAvailable:",
                "MemFree:",
                "SwapTotal:",
                "SwapFree:",
                "Dirty:",
                "Cached:",
            )
        )
    }
    vm = {
        key: int(value)
        for key, value in (
            line.split() for line in Path("/proc/vmstat").read_text().splitlines()
        )
        if key in {"pswpin", "pswpout", "pgmajfault", "oom_kill"}
    }
    gpu = call(
        [
            "nvidia-smi",
            "--query-gpu=temperature.gpu,power.draw,clocks.sm,clocks.mem,pstate,clocks_event_reasons.sw_thermal_slowdown,clocks_event_reasons.hw_thermal_slowdown,clocks_event_reasons.sw_power_cap",
            "--format=csv,noheader",
        ],
        timeout=10,
    )
    return {
        "unix": time.time(),
        "memory_kib": mem,
        "vmstat": vm,
        "gpu": gpu,
        "loadavg": Path("/proc/loadavg").read_text().strip(),
        "memory_pressure": Path("/proc/pressure/memory").read_text().strip(),
    }

