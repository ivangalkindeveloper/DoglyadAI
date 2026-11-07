"""Apply only N-gram engine arguments; retain the backend and rollback on failure."""

import fcntl
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

from observe import NAMES, idle, inspect, save, snapshot, telemetry

ROOT = Path(__file__).resolve().parent
HOST = Path("/opt/doglyad/inference")
FILES = [
    "docker-compose.yml",
    "profile.json",
    "host_profile.py",
    "compose_document.py",
    "start.py",
    "start.sh",
    ".env.example",
    "config/server.json",
]
SERVICES = ["vllm_medgemma_27b", "vllm_medgemma_4b", "vllm_medgemma_15_4b"]


def compose(*args):
    return [
        "docker",
        "compose",
        "--env-file",
        str(HOST / ".env"),
        "-f",
        str(HOST / "docker-compose.yml"),
        *args,
    ]


def run(command):
    subprocess.run(command, check=True, timeout=120)


def start(service, out):
    process = subprocess.Popen(
        compose(
            "up",
            "-d",
            "--no-deps",
            "--pull",
            "never",
            "--wait",
            "--wait-timeout",
            "1800",
            service,
        )
    )
    deadline = time.monotonic() + 1830
    while process.poll() is None:
        row = {**telemetry(), "service": service}
        out.write(json.dumps(row) + "\n")
        out.flush()
        if (
            row["memory_kib"]["MemAvailable"] < 4 * 1024 * 1024
            or time.monotonic() > deadline
        ):
            process.terminate()
            process.wait(timeout=30)
            raise RuntimeError("Startup memory/deadline guard")
        time.sleep(5)
    if process.returncode:
        raise RuntimeError(f"Engine startup failed: {service}")
    print(json.dumps({"healthy": service, "unix": time.time()}), flush=True)


def main():
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    stage = ROOT / "bundle"
    before = snapshot()
    save(ROOT / "deployment-before.json", before)
    old = json.loads((HOST / "docker-compose.yml").read_text())
    new = json.loads((stage / "docker-compose.yml").read_text())
    stripped = json.loads(json.dumps(new))
    stripped["x-doglyad-profile"] = old["x-doglyad-profile"]
    for service in SERVICES:
        command = stripped["services"][service]["command"]
        at = command.index("--speculative-config")
        assert json.loads(command[at + 1]) == {
            "method": "ngram",
            "num_speculative_tokens": 8,
            "prompt_lookup_min": 2,
            "prompt_lookup_max": 5,
        }
        del command[at : at + 2]
        assert command == inspect("doglyad-dgx-" + service + "-1")["Config"]["Cmd"]
    assert stripped == old, "Unexpected Compose change"
    assert (stage / "config/server.json").read_bytes() == (
        HOST / "config/server.json"
    ).read_bytes()
    for name in NAMES[:3]:
        idle(name)
    env_hash = hashlib.sha256((HOST / ".env").read_bytes()).hexdigest()
    backup = ROOT / "backup"
    backup.mkdir(mode=0o700, exist_ok=False)
    for name in FILES:
        (backup / name).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(HOST / name, backup / name)
    applied = False
    try:
        for name in FILES:
            shutil.copy2(stage / name, HOST / name)
        applied = True
        run(compose("config", "--quiet"))
        run(compose("stop", "--timeout", "30", *reversed(SERVICES)))
        with (ROOT / "startup-telemetry.jsonl").open("x") as out:
            for service in SERVICES:
                start(service, out)
        after = snapshot()
        assert after[NAMES[-1]] == before[NAMES[-1]], "Backend changed"
        assert all(after[n]["image"] == before[n]["image"] for n in NAMES)
        assert hashlib.sha256((HOST / ".env").read_bytes()).hexdigest() == env_hash
        save(ROOT / "deployment-after.json", after)
        save(
            ROOT / "deployment-status.json", {"status": "applied", "unix": time.time()}
        )
    except BaseException:
        if applied:
            run(compose("stop", "--timeout", "30", *reversed(SERVICES)))
        for name in FILES:
            shutil.copy2(backup / name, HOST / name)
        with (ROOT / "rollback-telemetry.jsonl").open("a") as out:
            for service in SERVICES:
                start(service, out)
        save(
            ROOT / "deployment-status.json",
            {"status": "rolled_back", "unix": time.time()},
        )
        raise


if __name__ == "__main__":
    main()
