"""Temporarily compare 2048/4096 and always restore initial engine commands."""

from __future__ import annotations

import argparse
import datetime
import fcntl
import hashlib
import json
from pathlib import Path
import signal
import subprocess
import time

from observe import NAMES, idle, save, snapshot, telemetry
from run_prefill import run

ROOT = Path(__file__).resolve().parent
HOST = Path("/opt/doglyad/inference")
SERVICES = ("vllm_medgemma_27b", "vllm_medgemma_4b", "vllm_medgemma_15_4b")


def compose(override: Path) -> list[str]:
    return [
        "docker",
        "compose",
        "--env-file",
        str(HOST / ".env"),
        "-f",
        str(HOST / "docker-compose.yml"),
        "-f",
        str(override),
    ]


def start(service: str, override: Path, log: object) -> None:
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
        log.write(json.dumps(row) + "\n")
        log.flush()
        if (
            row["memory_kib"]["MemAvailable"] < 6 * 1024**2
            or time.monotonic() > deadline
        ):
            process.terminate()
            process.wait(timeout=30)
            raise RuntimeError("Startup RAM/deadline guard")
        time.sleep(5)
    assert process.returncode == 0, f"Startup failed: {service}"
    print(json.dumps({"healthy": service, "override": override.name}), flush=True)


def stop(override: Path) -> None:
    subprocess.run(
        [*compose(override), "stop", "--timeout", "30", *reversed(SERVICES)],
        check=True,
        timeout=120,
    )


def interrupted(signum: int, frame: object) -> None:
    raise KeyboardInterrupt(f"Received signal {signum}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan-only", action="store_true")
    args = parser.parse_args()
    signal.signal(signal.SIGTERM, interrupted)
    lock_path = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock")
    lock_path.parent.mkdir(exist_ok=True)
    lock = lock_path.open("a")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    directory = ROOT / ("prefill-plan" if args.plan_only else "prefill-live")
    directory.mkdir(exist_ok=False)
    initial = snapshot()
    save(directory / "before.json", initial)
    since = datetime.datetime.now().astimezone().isoformat()
    canonical_paths = [
        HOST / "docker-compose.yml",
        HOST / "profile.json",
        HOST / "config/server.json",
    ]
    hashes = {
        str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in canonical_paths
    }
    save(directory / "canonical-hashes-before.json", hashes)
    document = json.loads((HOST / "docker-compose.yml").read_text())
    baseline, candidate = {}, {}
    for service in SERVICES:
        actual = initial["doglyad-dgx-" + service + "-1"]["command"]
        assert actual == document["services"][service]["command"], (
            "Canonical command differs from live engine"
        )
        assert actual[actual.index("--max-num-batched-tokens") + 1] == "2048"
        assert actual[actual.index("--max-num-seqs") + 1] == "8"
        assert "--speculative-config" in actual
        baseline[service] = {"command": actual}
        modified = list(actual)
        modified[modified.index("--max-num-batched-tokens") + 1] = "4096"
        candidate[service] = {"command": modified}
    original_override = directory / "original-commands.json"
    candidate_override = directory / "budget4096.json"
    save(original_override, {"services": baseline})
    save(candidate_override, {"services": candidate})
    subprocess.run(
        [*compose(candidate_override), "config", "--quiet"], check=True, timeout=30
    )
    if args.plan_only:
        print(
            json.dumps(
                {
                    "validated": True,
                    "engines": list(SERVICES),
                    "only_changed_argument": "--max-num-batched-tokens",
                    "from": 2048,
                    "to": 4096,
                    "restoration": "captured original command arrays",
                    "restarts_per_engine": 2,
                }
            ),
            flush=True,
        )
        return
    for name in NAMES[:3]:
        idle(name)
    is_changed, is_measured = False, False
    try:
        save(directory / "status.json", {"stage": "measuring2048", "since": since})
        run(2048, directory / "budget2048")
        for name in NAMES[:3]:
            idle(name)
        is_changed = True
        save(directory / "status.json", {"stage": "starting4096", "since": since})
        stop(candidate_override)
        with (directory / "startup4096.jsonl").open("x") as log:
            for service in SERVICES:
                start(service, candidate_override, log)
        actual = snapshot()
        assert actual[NAMES[3]] == initial[NAMES[3]], "Backend changed"
        assert all(actual[name]["image"] == initial[name]["image"] for name in NAMES)
        assert all(
            actual["doglyad-dgx-" + service + "-1"]["command"]
            == candidate[service]["command"]
            for service in SERVICES
        )
        save(directory / "status.json", {"stage": "measuring4096", "since": since})
        run(4096, directory / "budget4096")
        is_measured = True
    finally:
        # A later signal must not interrupt restoration after a requested stop.
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        if is_changed:
            save(directory / "status.json", {"stage": "restoring2048", "since": since})
            stop(original_override)
            with (directory / "restore2048.jsonl").open("x") as log:
                for service in SERVICES:
                    start(service, original_override, log)
        final = snapshot()
        save(directory / "after.json", final)
        assert final[NAMES[3]] == initial[NAMES[3]], "Backend changed"
        assert all(
            final[name]["command"] == initial[name]["command"]
            and final[name]["image"] == initial[name]["image"]
            and final[name]["running"]
            for name in NAMES
        )
        assert all(final[name]["health"] == "healthy" for name in NAMES[:3])
        assert hashes == {
            str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in canonical_paths
        }, "Canonical file changed"
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
            text=True,
            capture_output=True,
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
        save(
            directory / "status.json",
            {
                "stage": "complete_restored" if is_measured else "incomplete_restored",
                "since": since,
                "until": datetime.datetime.now().astimezone().isoformat(),
                "canonical_unchanged": True,
                "original_images_commands_restored": True,
            },
        )
        print(json.dumps({"complete": is_measured, "restored": True}), flush=True)


if __name__ == "__main__":
    main()
