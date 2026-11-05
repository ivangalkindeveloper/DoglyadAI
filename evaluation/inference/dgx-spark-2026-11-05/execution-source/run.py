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


def stop_temp(directory: Path) -> None:
    exists = (
        subprocess.run(
            ["docker", "inspect", TEMP],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )
    if exists:
        with (directory / "container.log").open("w") as output:
            subprocess.run(
                ["docker", "logs", TEMP],
                stdout=output,
                stderr=subprocess.STDOUT,
                timeout=60,
            )
        call(["docker", "rm", "-f", TEMP], timeout=60)


def run_probe(name: str, plan: dict, directory: Path) -> None:
    save(directory / "plan.json", plan)
    outputs = {}
    errors = (directory / "probe-stderr.log").open("w")
    process = subprocess.Popen(
        [
            "docker",
            "exec",
            "-i",
            name,
            "python3",
            "-c",
            (ROOT / "probe.py").read_text(),
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=errors,
        text=True,
    )
    assert process.stdin is not None and process.stdout is not None

    # A separate writer avoids a pipe deadlock for large JSON plans.
    def send() -> None:
        try:
            process.stdin.write(json.dumps(plan))
            process.stdin.close()
        except BrokenPipeError:
            pass

    sender = threading.Thread(target=send)
    sender.start()
    deadline = threading.Timer(3600, process.terminate)
    deadline.start()
    try:
        for line in process.stdout:
            value = json.loads(line)
            study = value["study"]
            if study not in outputs:
                target = ROOT / study / plan["model_key"] / plan["profile"]
                target.mkdir(parents=True, exist_ok=True)
                save(
                    target / "plan.json",
                    {k: v for k, v in plan.items() if k != "groups"},
                )
                outputs[study] = (target / "results.jsonl").open("x")
            outputs[study].write(line)
            outputs[study].flush()
            if value["event"] == "wave":
                event(
                    "wave",
                    model=plan["model_key"],
                    profile=plan["profile"],
                    group=value["group"],
                    wave=value["wave"],
                    seconds=value["seconds"],
                    valid=value["valid"],
                )
        code = process.wait(timeout=30)
        if code:
            raise RuntimeError(f"Probe exited {code}")
    finally:
        deadline.cancel()
        if process.poll() is None:
            process.terminate()
        sender.join(timeout=10)
        errors.close()
        for output in outputs.values():
            output.close()


def main() -> None:
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    before = snapshot()
    assert all(d["running"] for d in before.values())
    for name in NAMES[:3]:
        healthy(name)
        idle(name)
    save(ROOT / "runtime-before.json", before)
    save(ROOT / "host-before.json", telemetry())
    save(
        ROOT / "software.json",
        {
            "uname": call(["uname", "-a"]),
            "os": Path("/etc/os-release").read_text(),
            "docker": call(["docker", "version", "--format", "{{.Server.Version}}"]),
            "gpu": call(
                [
                    "nvidia-smi",
                    "--query-gpu=name,driver_version",
                    "--format=csv,noheader",
                ]
            ),
            "uptime": Path("/proc/uptime").read_text(),
        },
    )
    plans = json.loads((ROOT / "plan.json").read_text())
    stopped = set()
    finish = threading.Event()
    current = {"trial": "startup"}
    critical = []

    def monitor() -> None:
        path = ROOT / "07-host-health" / "telemetry.jsonl"
        with path.open("x") as out:
            while not finish.is_set():
                try:
                    value = {**telemetry(), **current}
                    out.write(json.dumps(value) + "\n")
                    out.flush()
                    if value["memory_kib"]["MemAvailable"] < 4 * 1024**2:
                        critical.append(value)
                        if (
                            subprocess.run(
                                ["docker", "inspect", TEMP],
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL,
                            ).returncode
                            == 0
                        ):
                            subprocess.run(
                                ["docker", "stop", "-t", "5", TEMP],
                                stdout=subprocess.DEVNULL,
                                timeout=30,
                            )
                except Exception as error:
                    out.write(
                        json.dumps({"unix": time.time(), "error": type(error).__name__})
                        + "\n"
                    )
                    out.flush()
                finish.wait(5)

    watcher = threading.Thread(target=monitor)
    watcher.start()

    def interrupted(signum: int, frame: object) -> None:
        raise RuntimeError(f"Interrupted {signum}")

    for s in [signal.SIGINT, signal.SIGTERM, signal.SIGHUP]:
        signal.signal(s, interrupted)
    last_directory = ROOT
    try:
        for index, original_name in enumerate(NAMES[:3]):
            model_plans = [p for p in plans if p["model_index"] == index]
            original = inspect(original_name)
            for plan in model_plans:
                if critical:
                    raise RuntimeError("Memory safety threshold reached")
                tag = plan["model_key"] + "-" + plan["profile"]
                directory = ROOT / "runs" / tag
                directory.mkdir(parents=True, exist_ok=False)
                last_directory = directory
                current["trial"] = tag
                event("trial_start", trial=tag)
                for name in NAMES[:3]:
                    if name not in stopped:
                        idle(name)
                if plan["profile"] == "baseline":
                    container = original_name
                else:
                    if original_name not in stopped:
                        call(["docker", "stop", "-t", "30", original_name], timeout=60)
                        stopped.add(original_name)
                    args = list(original["Config"]["Cmd"])
                    for flag, value in plan["flags"].items():
                        if flag in args:
                            args[args.index(flag) + 1] = value
                        else:
                            args += [flag, value]
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
                        "85g" if index == 2 else "30g",
                        "--memory-swap",
                        "85g" if index == 2 else "30g",
                        "--volumes-from",
                        original_name + ":ro",
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
                    started = time.monotonic()
                    call(command, timeout=60)
                    container = TEMP
                    try:
                        healthy(container)
                    except Exception as error:
                        save(
                            directory / "failure.json",
                            {
                                "phase": "startup",
                                "error": type(error).__name__,
                                "detail": str(error),
                            },
                        )
                        stop_temp(directory)
                        event("startup_failed", trial=tag)
                        continue
                    save(
                        directory / "startup.json",
                        {"seconds": time.monotonic() - started},
                    )
                save(directory / "host-before.json", telemetry())
                try:
                    run_probe(container, plan, directory)
                except Exception as error:
                    save(
                        directory / "failure.json",
                        {
                            "phase": "probe",
                            "error": type(error).__name__,
                            "detail": str(error),
                        },
                    )
                    event("probe_failed", trial=tag, error=str(error))
                finally:
                    if container == TEMP:
                        stop_temp(directory)
                save(directory / "host-after.json", telemetry())
                event("trial_end", trial=tag)
            if original_name in stopped:
                call(["docker", "start", original_name], timeout=60)
                healthy(original_name)
                stopped.remove(original_name)
                event("model_restored", model=index)
    finally:
        current["trial"] = "restoration"
        stop_temp(last_directory)
        for name in NAMES[:3]:
            if name in stopped or not inspect(name)["State"]["Running"]:
                call(["docker", "start", name], timeout=60)
            healthy(name)
        finish.set()
        watcher.join(timeout=20)
        after = snapshot()
        save(ROOT / "runtime-after.json", after)
        checks = {}
        for name in NAMES:
            checks[name] = {
                key: before[name][key] == after[name][key]
                for key in ["id", "image", "command", "restart_policy"]
            }
            checks[name]["running"] = after[name]["running"]
        save(ROOT / "restoration.json", checks)
        assert all(all(values.values()) for values in checks.values()), checks
        event("restored")


if __name__ == "__main__":
    main()
