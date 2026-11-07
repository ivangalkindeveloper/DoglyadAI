"""Scoped, reversible engine-profile experiments. Never edits canonical files."""

import datetime
import fcntl
import json
from pathlib import Path
import subprocess
import sys
import time

from experiment import run
from observe import NAMES, idle, save, snapshot, telemetry

ROOT = Path(__file__).resolve().parent
HOST = Path("/opt/doglyad/inference")
SERVICES = ["vllm_medgemma_27b", "vllm_medgemma_4b", "vllm_medgemma_15_4b"]
PROFILES = {
    "baseline": (4, 8),
    "seq8": (8, 8),
    "seq8-kv12": (8, 12),
    "seq4-kv12": (4, 12),
}


def compose(override=None):
    args = [
        "docker",
        "compose",
        "--env-file",
        str(HOST / ".env"),
        "-f",
        str(HOST / "docker-compose.yml"),
    ]
    return args + (["-f", str(override)] if override else [])


def start(service, override, output):
    process = subprocess.Popen(
        [
            *compose(override),
            "up",
            "-d",
            "--no-deps",
            "--pull",
            "never",
            "--wait",
            "--wait-timeout",
            "1800",
            service,
        ]
    )
    deadline = time.monotonic() + 1830
    while process.poll() is None:
        row = {**telemetry(), "service": service}
        output.write(json.dumps(row) + "\n")
        output.flush()
        if (
            row["memory_kib"]["MemAvailable"] < 6 * 1024**2
            or time.monotonic() > deadline
        ):
            process.terminate()
            process.wait(timeout=30)
            raise RuntimeError("Startup RAM/deadline guard")
        time.sleep(5)
    if process.returncode:
        raise RuntimeError("Engine startup failed")
    print(json.dumps({"healthy": service}), flush=True)


def main():
    profile = sys.argv[1]
    seqs, kv = PROFILES[profile]
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    directory = ROOT / profile
    directory.mkdir(exist_ok=False)
    initial = snapshot()
    save(directory / "before.json", initial)
    since = datetime.datetime.now().astimezone().isoformat()
    save(directory / "status.json", {"status": "starting", "since": since})
    document = json.loads((HOST / "docker-compose.yml").read_text())
    overrides = {}
    for service in SERVICES:
        command = list(document["services"][service]["command"])
        assert (
            "--speculative-config" in command
            and command[command.index("--max-num-seqs") + 1] == "4"
        )
        command[command.index("--max-num-seqs") + 1] = str(seqs)
        if service == "vllm_medgemma_27b":
            command[command.index("--kv-cache-memory-bytes") + 1] = str(kv * 1024**3)
        overrides[service] = {"command": command}
    override = directory / "override.json"
    save(override, {"services": overrides})
    changed = [
        s
        for s in SERVICES
        if initial["doglyad-dgx-" + s + "-1"]["command"] != overrides[s]["command"]
    ]
    for name in NAMES[:3]:
        idle(name)
    try:
        subprocess.run(
            [*compose(override), "config", "--quiet"], check=True, timeout=30
        )
        if changed:
            subprocess.run(
                [*compose(override), "stop", "--timeout", "30", *reversed(changed)],
                check=True,
                timeout=120,
            )
            with (directory / "startup.jsonl").open("x") as output:
                for service in changed:
                    start(service, override, output)
        actual = snapshot()
        assert actual[NAMES[3]] == initial[NAMES[3]]
        assert all(actual[n]["image"] == initial[n]["image"] for n in NAMES)
        assert all(
            actual["doglyad-dgx-" + s + "-1"]["command"] == overrides[s]["command"]
            for s in SERVICES
        )
        save(directory / "status.json", {"status": "measuring", "since": since})
        run(profile, directory / "measurements")
        save(
            directory / "status.json",
            {
                "status": "complete",
                "since": since,
                "until": datetime.datetime.now().astimezone().isoformat(),
            },
        )
    except BaseException as error:
        save(
            directory / "status.json",
            {
                "status": "failed_restoring",
                "error": type(error).__name__,
                "since": since,
            },
        )
        subprocess.run(
            [*compose(), "stop", "--timeout", "30", *reversed(SERVICES)],
            check=True,
            timeout=120,
        )
        with (directory / "restore.jsonl").open("x") as output:
            for service in SERVICES:
                start(service, None, output)
        save(
            directory / "status.json",
            {
                "status": "failed_baseline_restored",
                "error": type(error).__name__,
                "since": since,
            },
        )
        raise
    finally:
        result = subprocess.run(
            [
                "journalctl",
                "-k",
                "-b",
                "--no-pager",
                "-o",
                "short-iso",
                "--since",
                since,
                "--grep",
                "NVRM: Xid|Out of memory|oom-kill|GPU has fallen off|NV_ERR_NO_MEMORY",
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        save(
            directory / "kernel.json",
            {
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
            },
        )
        save(directory / "after.json", snapshot())
        for service in SERVICES:
            with (directory / (service + ".log")).open("w") as output:
                subprocess.run(
                    [
                        "docker",
                        "logs",
                        "--since",
                        since,
                        "doglyad-dgx-" + service + "-1",
                    ],
                    stdout=output,
                    stderr=subprocess.STDOUT,
                    timeout=30,
                )


if __name__ == "__main__":
    main()
