"""Run on DGX after eager baseline; restore the original container in finally."""
from __future__ import annotations

import argparse
import hashlib
import json
import signal
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

ORIGINAL = "doglyad-dgx-vllm_medgemma_4b-1"
BACKEND = "doglyad-dgx-backend_inference-1"
OTHERS = ["doglyad-dgx-vllm_medgemma_15_4b-1", "doglyad-dgx-vllm_medgemma_27b-1", BACKEND]
TEST = "doglyad-evaluation-medgemma-4b"


def _command(args: list[str], is_checked: bool = True, timeout: int = 60) -> str:
    result = subprocess.run(args, text=True, capture_output=True, timeout=timeout)
    if is_checked and result.returncode:
        raise RuntimeError(f"Command failed: {args[:2]}, exit={result.returncode}")
    return result.stdout


def _inspect(name: str) -> dict:
    return json.loads(_command(["docker", "inspect", name]))[0]


def _memory() -> dict:
    values = {line.split(":")[0]: int(line.split()[1])*1024 for line in Path("/proc/meminfo").read_text().splitlines()}
    return {k: values[k] for k in ["MemTotal", "MemAvailable", "SwapTotal", "SwapFree"]}


def _snapshot() -> dict:
    containers = []
    for name in [ORIGINAL, *OTHERS]:
        c = _inspect(name)
        containers.append({"name": name, "id": c["Id"], "image": c["Image"], "command": c["Config"]["Cmd"],
                           "state": c["State"]["Status"], "started_at": c["State"]["StartedAt"],
                           "restart_count": c["RestartCount"], "health": c["State"].get("Health", {}).get("Status")})
    directory = Path("/opt/doglyad/inference")
    return {"time": datetime.now(timezone.utc).isoformat(), "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
            "memory": _memory(), "containers": containers,
            "file_sha256": {p: hashlib.sha256((directory/p).read_bytes()).hexdigest() for p in ["docker-compose.yml", "config/server.json"]}}


def _health(name: str) -> bool:
    result = subprocess.run(["docker", "exec", name, "python3", "-c",
                             "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health',timeout=3)"],
                            capture_output=True, timeout=15)
    return result.returncode == 0


def _wait_health(name: str, timeout: int = 1200) -> None:
    deadline = time.monotonic()+timeout
    while time.monotonic() < deadline:
        if _inspect(name)["State"]["Status"] != "running":
            raise RuntimeError("Engine exited before readiness")
        if _health(name):
            return
        if _memory()["MemAvailable"] < 4*1024**3:
            raise RuntimeError("Safety stop: less than 4 GiB available RAM")
        time.sleep(5)
    raise TimeoutError("Engine startup timeout")


def _metrics(name: str) -> str:
    return _command(["docker", "exec", name, "python3", "-c",
                     "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/metrics',timeout=5).read().decode())"], is_checked=False)


def _run_monitored(command: list[str], log: Path, telemetry: Path, name: str) -> int:
    started = time.monotonic()
    with log.open("w") as stream, telemetry.open("a") as stats:
        process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT)
        try:
            while process.poll() is None:
                memory = _memory()
                stats.write(json.dumps({"time": datetime.now(timezone.utc).isoformat(), "memory": memory,
                                       "gpu": _command(["nvidia-smi", "--query-gpu=temperature.gpu,utilization.gpu,power.draw", "--format=csv,noheader,nounits"], is_checked=False).strip()})+"\n")
                stats.flush()
                if memory["MemAvailable"] < 4*1024**3 or time.monotonic()-started > 2400:
                    raise RuntimeError("Safety stop: RAM threshold or benchmark deadline")
                time.sleep(5)
            return process.returncode
        finally:
            if process.poll() is None:
                # Stopping the isolated engine also cancels docker-exec work.
                _command(["docker", "stop", "-t", "15", name], is_checked=False)
                process.terminate()
                process.wait(timeout=30)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True)
    args = parser.parse_args()
    directory = Path(args.directory).resolve()
    directory.mkdir(parents=True, exist_ok=True)
    # The baseline runs separately on the untouched original container.
    deadline = time.monotonic()+1200
    while True:
        status = _command(["docker", "exec", ORIGINAL, "python3", "-c",
                           "import json; print(bool(json.load(open('/tmp/dgx-eager-1.json')).get('finished_at')))"], is_checked=False)
        if status.strip() == "True":
            break
        if time.monotonic() > deadline:
            raise TimeoutError("Baseline did not complete; original container remains untouched")
        time.sleep(10)
    _command(["docker", "cp", f"{ORIGINAL}:/tmp/dgx-eager-1.json", str(directory/"eager-1.json")])
    report = {"before": _snapshot(), "variants": [], "is_restored": False}
    original = _inspect(ORIGINAL)
    if not _health(ORIGINAL):
        raise RuntimeError("Original model is not healthy")
    existing = _command(["docker", "ps", "-a", "--filter", f"name=^/{TEST}$", "--format", "{{.ID}}"])
    if existing.strip():
        raise RuntimeError("Evaluation container already exists")
    for name in [ORIGINAL, *OTHERS[:2]]:
        metrics = _metrics(name)
        (directory/f"{name}.metrics-before.txt").write_text(metrics)
        for line in metrics.splitlines():
            if line.startswith(("vllm:num_requests_running{", "vllm:num_requests_waiting{")) and float(line.rsplit(" ", 1)[1]):
                raise RuntimeError("An engine is serving requests")
    (directory/"conditions.json").write_text(json.dumps(report, indent=2))
    _command(["docker", "cp", str(directory/"service_probe.py"), f"{BACKEND}:/tmp/dgx_service_probe.py"])

    def stop(signum: int, frame: object) -> None:
        raise InterruptedError(f"Signal {signum}")

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        _command(["docker", "stop", "-t", "30", ORIGINAL], timeout=90)
        for variant, is_eager, sequences in [("compiled-1", False, 1), ("eager-8", True, 8), ("compiled-8", False, 8)]:
            print(f"START {variant}", flush=True)
            entry = {"variant": variant, "is_eager": is_eager, "max_num_seqs": sequences, "started_at": datetime.now(timezone.utc).isoformat()}
            report["variants"].append(entry)
            command = list(original["Config"]["Cmd"])
            if not is_eager:
                command.remove("--enforce-eager")
            command[command.index("--max-num-seqs")+1] = str(sequences)
            command += ["--revision", "290cda5eeccbee130f987c4ad74a59ae6f196408"]
            entry["command"] = command
            docker = ["docker", "run", "-d", "--name", TEST, "--restart", "no", "--network", "doglyad-dgx_default",
                      "--gpus", "all", "--shm-size", str(original["HostConfig"]["ShmSize"]),
                      "--mount", "type=volume,source=doglyad-dgx-huggingface,target=/root/.cache/huggingface",
                      "-e", "HF_HUB_OFFLINE=1", "-e", "TRANSFORMERS_OFFLINE=1", original["Image"], *command]
            started = time.monotonic()
            try:
                entry["container_id"] = _command(docker).strip()
                _wait_health(TEST)
                entry["startup_seconds"] = time.monotonic()-started
                entry["memory_ready"] = _memory()
                _command(["docker", "cp", str(directory/"benchmark.py"), f"{TEST}:/tmp/dgx_benchmark.py"])
                (directory/f"{variant}.metrics-before.txt").write_text(_metrics(TEST))
                bench = ["docker", "exec", TEST, "python3", "/tmp/dgx_benchmark.py", "--variant", variant, "--output", "/tmp/results.json"]
                if sequences > 1:
                    bench.append("--is-load")
                entry["benchmark_exit"] = _run_monitored(bench, directory/f"{variant}.progress", directory/f"{variant}.telemetry.jsonl", TEST)
                _command(["docker", "cp", f"{TEST}:/tmp/results.json", str(directory/f"{variant}.json")], is_checked=False)
                if sequences > 1:
                    probe = ["docker", "exec", "-e", "PYTHONPATH=/app", BACKEND, "python3", "/tmp/dgx_service_probe.py",
                             "--url", f"http://{TEST}:8000", "--variant", variant, "--output", "/tmp/dgx-service-results.json"]
                    entry["service_probe_exit"] = _run_monitored(probe, directory/f"{variant}.service.progress", directory/f"{variant}.telemetry.jsonl", TEST)
                    _command(["docker", "cp", f"{BACKEND}:/tmp/dgx-service-results.json", str(directory/f"{variant}.service.json")], is_checked=False)
                (directory/f"{variant}.metrics-after.txt").write_text(_metrics(TEST))
            except Exception as error:
                entry["error"] = f"{type(error).__name__}: {error}"
                print(f"ERROR {variant}: {entry['error']}", flush=True)
            finally:
                log = subprocess.run(["docker", "logs", TEST], capture_output=True, text=True)
                (directory/f"{variant}.engine.log").write_text(log.stdout+log.stderr)
                _command(["docker", "rm", "-f", TEST], is_checked=False)
                entry["finished_at"] = datetime.now(timezone.utc).isoformat()
                (directory/"conditions.json").write_text(json.dumps(report, indent=2))
            print(f"FINISH {variant}", flush=True)
            kernel = _command(["journalctl", "-k", "-b", "--since", report["before"]["time"], "--no-pager"], is_checked=False)
            if any(x in kernel for x in ["NVRM: Xid", "oom-kill", "Out of memory"]):
                raise RuntimeError("New GPU or out-of-memory kernel event; stop further variants")
    finally:
        _command(["docker", "rm", "-f", TEST], is_checked=False)
        _command(["docker", "start", ORIGINAL])
        _wait_health(ORIGINAL)
        report["after"] = _snapshot()
        report["is_restored"] = report["before"]["file_sha256"] == report["after"]["file_sha256"]
        for before, after in zip(report["before"]["containers"], report["after"]["containers"]):
            report["is_restored"] &= before["id"] == after["id"] and before["image"] == after["image"] and before["command"] == after["command"] and after["state"] == "running"
        for name in [ORIGINAL, *OTHERS[:2]]:
            (directory/f"{name}.metrics-after.txt").write_text(_metrics(name))
        journal = subprocess.run(["journalctl", "-k", "-b", "--since", report["before"]["time"], "--no-pager"], capture_output=True, text=True)
        report["kernel_check"] = {"exit": journal.returncode, "events": [line for line in journal.stdout.splitlines() if any(x in line for x in ["NVRM: Xid", "oom-kill", "Out of memory"])]}
        (directory/"conditions.json").write_text(json.dumps(report, indent=2))
        print(f"RESTORED {report['is_restored']}", flush=True)


if __name__ == "__main__":
    main()
