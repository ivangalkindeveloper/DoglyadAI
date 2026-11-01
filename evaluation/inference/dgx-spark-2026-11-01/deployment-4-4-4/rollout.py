"""Apply the reviewed generated DGX profile; restore previous files on startup failure."""

import fcntl
import hashlib
import json
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

HOST = Path("/opt/doglyad/inference")
STAGE = Path(__file__).resolve().parent
FILES = [
    "docker-compose.yml",
    "start.sh",
    "start.py",
    "host_profile.py",
    "compose_document.py",
    "profile.json",
    "config/server.json",
    ".env.example",
]


def run(args, **kwargs):
    return subprocess.run(args, cwd=HOST, check=True, **kwargs)


def snapshot():
    ids = run(
        [
            "docker",
            "ps",
            "-aq",
            "--filter",
            "label=com.docker.compose.project=doglyad-dgx",
        ],
        capture_output=True,
        text=True,
    ).stdout.split()
    rows = json.loads(
        run(["docker", "inspect", *ids], capture_output=True, text=True).stdout
    )
    return {
        "time": datetime.now(timezone.utc).isoformat(),
        "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
        "meminfo": Path("/proc/meminfo").read_text(),
        "files": {
            f: hashlib.sha256((HOST / f).read_bytes()).hexdigest()
            for f in FILES
            if (HOST / f).is_file()
        },
        "containers": [
            {
                "name": r["Name"],
                "id": r["Id"],
                "image": r["Image"],
                "command": r["Config"].get("Cmd"),
                "state": r["State"],
                "restarts": r["RestartCount"],
                "ports": r["HostConfig"]["PortBindings"],
            }
            for r in rows
        ],
    }


def main():
    with (HOST / ".infrastructure-operation-lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        assert not (HOST / ".infrastructure-update-lock").exists()
        backup = STAGE / "backup"
        backup.mkdir(mode=0o700)
        before = snapshot()
        (STAGE / "before.json").write_text(json.dumps(before, indent=2))
        for f in FILES:
            source = HOST / f
            if source.is_file():
                destination = backup / f
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, destination)
        shutil.copy2(HOST / ".env", backup / ".env")
        (backup / ".env").chmod(0o600)
        assert {
            r["name"].lstrip("/") for r in before["containers"] if r["state"]["Running"]
        } == {
            "doglyad-dgx-backend_inference-1",
            "doglyad-dgx-vllm_medgemma_27b-1",
            "doglyad-dgx-vllm_medgemma_4b-1",
            "doglyad-dgx-vllm_medgemma_15_4b-1",
        }
        # Check idle engines before stopping the live stack.
        for model in json.loads((STAGE / "generated/profile.json").read_text())[
            "models"
        ]:
            script = "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/metrics',timeout=10).read().decode())"
            metrics = run(
                [
                    "docker",
                    "exec",
                    "doglyad-dgx-" + model["service"] + "-1",
                    "python3",
                    "-c",
                    script,
                ],
                capture_output=True,
                text=True,
            ).stdout
            for line in metrics.splitlines():
                if line.startswith(
                    ("vllm:num_requests_running{", "vllm:num_requests_waiting{")
                ):
                    assert float(line.rsplit(" ", 1)[1]) == 0, "Engine is busy"
        try:
            for f in FILES:
                destination = HOST / f
                destination.parent.mkdir(parents=True, exist_ok=True)
                temporary = destination.with_name(destination.name + ".deploy444")
                shutil.copy2(STAGE / "generated" / f, temporary)
                temporary.chmod(0o644)
                temporary.replace(destination)
            run(["docker", "compose", "--env-file", ".env", "config", "--quiet"])
            run(["bash", "start.sh", "--restart"])
        except BaseException:
            print(
                "Startup failed; restoring previous files and startup script.",
                flush=True,
            )
            for f in FILES:
                if (backup / f).exists():
                    shutil.copy2(backup / f, HOST / f)
                else:
                    (HOST / f).unlink(missing_ok=True)
            run(["bash", "start.sh", "--restart"])
            (STAGE / "status.json").write_text(json.dumps({"status": "rolled_back"}))
            raise
        (STAGE / "after-startup.json").write_text(json.dumps(snapshot(), indent=2))
        (STAGE / "status.json").write_text(
            json.dumps(
                {"status": "started", "time": datetime.now(timezone.utc).isoformat()}
            )
        )
        print(
            "Generated 4/4/4 stack started; generation verification follows.",
            flush=True,
        )


if __name__ == "__main__":
    main()
