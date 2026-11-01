"""Temporary 4+4+4 engines, monitored benchmark, and sequential restoration."""

from __future__ import annotations

import argparse
import hashlib
import json
import signal
import subprocess
import threading
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import host_helpers as host


def _watch_resources(directory: Path, phase: list[str], stop: threading.Event) -> None:
    with (directory / "resources.jsonl").open("w") as stream:
        while not stop.is_set():
            values = dict(
                line.split() for line in Path("/proc/vmstat").read_text().splitlines()
            )
            stream.write(
                json.dumps(
                    {
                        "time": datetime.now(timezone.utc).isoformat(),
                        "phase": phase[0],
                        "memory": host._memory(),
                        "vmstat": {
                            k: int(values[k])
                            for k in ["pswpin", "pswpout", "pgmajfault"]
                        },
                    }
                )
                + "\n"
            )
            stream.flush()
            stop.wait(5)


def _kernel_events(since: str) -> list[str]:
    result = subprocess.run(
        ["journalctl", "-k", "-b", "--since", since, "--no-pager"],
        capture_output=True,
        text=True,
        timeout=15,
    )
    if result.returncode:
        raise RuntimeError("Kernel log could not be read")
    return [
        line
        for line in result.stdout.splitlines()
        if any(x in line for x in ["NVRM: Xid", "oom-kill", "Out of memory"])
    ]


def _metrics(name: str) -> dict:
    info = host._inspect(name)
    address = info["NetworkSettings"]["Networks"]["doglyad-dgx_default"]["IPAddress"]
    client = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with client.open(f"http://{address}:8000/metrics", timeout=3) as response:
        lines = response.read().decode().splitlines()
    values = {}
    for line in lines:
        for field in [
            "num_requests_running",
            "num_requests_waiting",
            "num_preemptions_total",
            "kv_cache_usage_perc",
            "gpu_cache_usage_perc",
        ]:
            if line.startswith("vllm:" + field + "{"):
                values[field] = values.get(field, 0) + float(line.rsplit(" ", 1)[1])
    return values


def _monitored(
    command: list[str], directory: Path, label: str, targets: list[dict], since: str
) -> int:
    started = time.monotonic()
    with (
        (directory / (label + ".progress")).open("w") as log,
        (directory / "telemetry.jsonl").open("a") as stats,
    ):
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        try:
            while process.poll() is None:
                memory = host._memory()
                record = {
                    "time": datetime.now(timezone.utc).isoformat(),
                    "phase": label,
                    "memory": memory,
                    "gpu": host._command(
                        [
                            "nvidia-smi",
                            "--query-gpu=temperature.gpu,utilization.gpu,power.draw",
                            "--format=csv,noheader,nounits",
                        ],
                        timeout=15,
                    ).strip(),
                    "engines": {
                        t["key"]: _metrics(t["test_container"]) for t in targets
                    },
                }
                stats.write(json.dumps(record) + "\n")
                stats.flush()
                if memory["MemAvailable"] < 4 * 1024**3:
                    raise RuntimeError("Less than 4 GiB available RAM")
                if _kernel_events(since):
                    raise RuntimeError("New GPU or OOM event")
                if time.monotonic() - started > 3600:
                    raise TimeoutError("Benchmark deadline")
                time.sleep(5)
            return process.returncode
        finally:
            if process.poll() is None:
                host._command(
                    [
                        "docker",
                        "stop",
                        "-t",
                        "10",
                        *[t["test_container"] for t in targets],
                    ],
                    is_checked=False,
                )
                process.terminate()
                process.wait(timeout=30)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True)
    args = parser.parse_args()
    directory = Path(args.directory).resolve()
    targets = json.loads((directory / "candidate-targets.json").read_text())
    startup_order = sorted(targets, key=lambda t: 0 if t["key"] == "27b" else 1)
    report = {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "before": host._snapshot(),
        "engines": [],
        "is_restored": False,
        "startup_order": [t["key"] for t in startup_order],
        "preexisting_kernel_events": _kernel_events("-1 hour"),
    }
    report["runner_sha256"] = {
        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in directory.glob("*.py")
    }
    original = {t["key"]: host._inspect(t["original_container"]) for t in targets}
    assert all(
        info["Image"]
        == "sha256:89154ef00dd15368d2b293c167e5cc7dbb521fcfb2fbb77510e0d4df2b820e8f"
        for info in original.values()
    )
    for t in targets:
        existing = host._command(
            [
                "docker",
                "ps",
                "-a",
                "--filter",
                f"name=^/{t['test_container']}$",
                "--format",
                "{{.ID}}",
            ]
        )
        if existing.strip():
            raise RuntimeError("A test container already exists")
    (directory / "conditions.json").write_text(json.dumps(report, indent=2))
    for t in targets:
        counters = _metrics(t["original_container"])
        if counters.get("num_requests_running", 0) or counters.get(
            "num_requests_waiting", 0
        ):
            raise RuntimeError("Original engine is busy")

    def stop(signum: int, frame: object) -> None:
        raise KeyboardInterrupt(f"Signal {signum}")

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    phase = ["stop-originals"]
    resource_stop = threading.Event()
    watcher = threading.Thread(
        target=_watch_resources, args=(directory, phase, resource_stop), daemon=True
    )
    watcher.start()
    try:
        print("STOP originals", flush=True)
        host._command(
            ["docker", "stop", "-t", "30", *[t["original_container"] for t in targets]],
            timeout=120,
        )
        for t in startup_order:
            name = t["test_container"]
            phase[0] = "startup-" + t["key"]
            print("START " + name, flush=True)
            command = list(original[t["key"]]["Config"]["Cmd"])
            command.remove("--enforce-eager")
            command[command.index("--max-num-seqs") + 1] = str(t["concurrency"])
            command += ["--revision", t["revision"]]
            entry = {
                "key": t["key"],
                "command": command,
                "image": original[t["key"]]["Image"],
            }
            report["engines"].append(entry)
            (directory / "conditions.json").write_text(json.dumps(report, indent=2))
            started = time.monotonic()
            host._command(
                [
                    "docker",
                    "run",
                    "-d",
                    "--name",
                    name,
                    "--restart",
                    "no",
                    "--network",
                    "doglyad-dgx_default",
                    "--gpus",
                    "all",
                    "--shm-size",
                    str(original[t["key"]]["HostConfig"]["ShmSize"]),
                    "--mount",
                    "type=volume,source=doglyad-dgx-huggingface,target=/root/.cache/huggingface",
                    "-e",
                    "HF_HUB_OFFLINE=1",
                    "-e",
                    "TRANSFORMERS_OFFLINE=1",
                    entry["image"],
                    *command,
                ]
            )
            host._wait_health(name, timeout=1800)
            entry["startup_seconds"] = time.monotonic() - started
            entry["memory_ready"] = host._memory()
            (directory / "conditions.json").write_text(json.dumps(report, indent=2))
            if _kernel_events(report["started_at"]):
                raise RuntimeError("Kernel error during startup")
            print("READY " + name, flush=True)
        runner = targets[0]["test_container"]
        phase[0] = "candidate"
        for file in ["benchmark_matrix.py", "fixtures.py", "candidate-targets.json"]:
            host._command(
                ["docker", "cp", str(directory / file), runner + ":/tmp/" + file]
            )
        report["benchmark_exit"] = _monitored(
            [
                "docker",
                "exec",
                runner,
                "python3",
                "/tmp/benchmark_matrix.py",
                "--stage",
                "candidate",
                "--targets",
                "/tmp/candidate-targets.json",
                "--output",
                "/tmp/results444.json",
            ],
            directory,
            "candidate",
            targets,
            report["started_at"],
        )
        host._command(
            [
                "docker",
                "cp",
                runner + ":/tmp/results444.json",
                str(directory / "candidate.json"),
            ],
            is_checked=False,
        )
        if report["benchmark_exit"] != 0:
            raise RuntimeError("Benchmark failed; see partial result")
        report["candidate_finished_at"] = datetime.now(timezone.utc).isoformat()
        report["kernel_events_after_candidate"] = _kernel_events(report["started_at"])
        phase[0] = "service"
        for file in ["service_matrix.py", "candidate-targets.json"]:
            host._command(
                ["docker", "cp", str(directory / file), host.BACKEND + ":/tmp/" + file]
            )
        report["service_exit"] = _monitored(
            [
                "docker",
                "exec",
                "-e",
                "PYTHONPATH=/app",
                host.BACKEND,
                "python3",
                "/tmp/service_matrix.py",
                "--targets",
                "/tmp/candidate-targets.json",
                "--output",
                "/tmp/service444.json",
            ],
            directory,
            "service",
            targets,
            report["started_at"],
        )
        host._command(
            [
                "docker",
                "cp",
                host.BACKEND + ":/tmp/service444.json",
                str(directory / "service.json"),
            ],
            is_checked=False,
        )
        report["service_finished_at"] = datetime.now(timezone.utc).isoformat()
        report["kernel_events_after_service"] = _kernel_events(report["started_at"])
    except (Exception, KeyboardInterrupt) as error:
        report["error"] = f"{type(error).__name__}: {error}"
        print("ERROR " + report["error"], flush=True)
        host._command(
            [
                "docker",
                "cp",
                targets[0]["test_container"] + ":/tmp/results444.json",
                str(directory / "candidate.json"),
            ],
            is_checked=False,
        )
    finally:
        phase[0] = "remove-temporary"
        report["restoration_started_at"] = datetime.now(timezone.utc).isoformat()
        print("RESTORE originals", flush=True)
        for t in targets:
            log = subprocess.run(
                ["docker", "logs", t["test_container"]],
                capture_output=True,
                text=True,
                timeout=30,
            )
            (directory / (t["key"] + ".engine.log")).write_text(log.stdout + log.stderr)
            host._command(["docker", "rm", "-f", t["test_container"]], is_checked=False)
        report["restoration_errors"] = []
        for t in startup_order:
            phase[0] = "restore-" + t["key"]
            try:
                host._command(["docker", "start", t["original_container"]])
                host._wait_health(t["original_container"], timeout=1800)
                print("RESTORED " + t["key"], flush=True)
            except Exception as error:
                report["restoration_errors"].append(
                    {"key": t["key"], "error": f"{type(error).__name__}: {error}"}
                )
                print("RESTORE FAILED " + t["key"], flush=True)
        report["after"] = host._snapshot()
        report["kernel_events"] = _kernel_events(report["started_at"])
        report["is_restored"] = (
            not report["restoration_errors"]
            and report["before"]["boot_id"] == report["after"]["boot_id"]
            and report["before"]["file_sha256"] == report["after"]["file_sha256"]
        )
        for before, after in zip(
            report["before"]["containers"], report["after"]["containers"]
        ):
            report["is_restored"] &= (
                before["id"] == after["id"]
                and before["command"] == after["command"]
                and before["image"] == after["image"]
                and after["state"] == "running"
            )
        (directory / "conditions.json").write_text(json.dumps(report, indent=2))
        resource_stop.set()
        watcher.join(timeout=10)
        print("COMPLETE restored=" + str(report["is_restored"]), flush=True)
    if report.get("error") or not report["is_restored"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
