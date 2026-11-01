"""Temporary 4+4+2 engines, monitored benchmark, and sequential restoration."""

from __future__ import annotations

import argparse
import hashlib
import json
import signal
import subprocess
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import host_helpers as host


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
    report = {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "before": host._snapshot(),
        "engines": [],
        "is_restored": False,
    }
    report["runner_sha256"] = {
        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in directory.glob("*.py")
    }
    original = {t["key"]: host._inspect(t["original_container"]) for t in targets}
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
    deadline = time.monotonic() + 1200
    while True:
        status = host._command(
            [
                "docker",
                "exec",
                targets[0]["original_container"],
                "python3",
                "-c",
                "import json; print(bool(json.load(open('/tmp/results442-baseline.json')).get('finished_at')))",
            ],
            is_checked=False,
        )
        if status.strip() == "True":
            break
        if (
            "Traceback" in (directory / "baseline.progress").read_text()
            or time.monotonic() > deadline
        ):
            raise RuntimeError("Baseline failed; original containers untouched")
        time.sleep(5)
    host._command(
        [
            "docker",
            "cp",
            targets[0]["original_container"] + ":/tmp/results442-baseline.json",
            str(directory / "baseline.json"),
        ]
    )
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
    try:
        print("STOP originals", flush=True)
        host._command(
            ["docker", "stop", "-t", "30", *[t["original_container"] for t in targets]],
            timeout=120,
        )
        for t in targets:
            name = t["test_container"]
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
            if _kernel_events(report["started_at"]):
                raise RuntimeError("Kernel error during startup")
            print("READY " + name, flush=True)
        runner = targets[0]["test_container"]
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
                "/tmp/results442.json",
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
                runner + ":/tmp/results442.json",
                str(directory / "candidate.json"),
            ],
            is_checked=False,
        )
        if report["benchmark_exit"] != 0:
            raise RuntimeError("Benchmark failed; see partial result")
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
                "/tmp/service442.json",
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
                host.BACKEND + ":/tmp/service442.json",
                str(directory / "service.json"),
            ],
            is_checked=False,
        )
    except Exception as error:
        report["error"] = f"{type(error).__name__}: {error}"
        print("ERROR " + report["error"], flush=True)
        host._command(
            [
                "docker",
                "cp",
                targets[0]["test_container"] + ":/tmp/results442.json",
                str(directory / "candidate.json"),
            ],
            is_checked=False,
        )
    finally:
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
        for t in targets:
            host._command(["docker", "start", t["original_container"]])
            host._wait_health(t["original_container"], timeout=1800)
            print("RESTORED " + t["key"], flush=True)
        report["after"] = host._snapshot()
        report["kernel_events"] = _kernel_events(report["started_at"])
        report["is_restored"] = (
            report["before"]["boot_id"] == report["after"]["boot_id"]
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
        print("COMPLETE restored=" + str(report["is_restored"]), flush=True)


if __name__ == "__main__":
    main()
