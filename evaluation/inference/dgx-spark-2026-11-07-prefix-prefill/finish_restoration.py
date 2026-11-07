"""Wait for Docker's existing restart policy after the controller's failed wait."""

from __future__ import annotations

import datetime
import fcntl
import hashlib
import json
import subprocess
import time
from pathlib import Path

from observe import NAMES, ROOT, save, snapshot, telemetry


def main() -> None:
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    directory = ROOT / "prefill-live"
    initial = json.loads((directory / "before.json").read_text())
    status = json.loads((directory / "status.json").read_text())
    save(directory / "controller-status.json", status)
    deadline = time.monotonic() + 900
    with (directory / "recovery-wait.jsonl").open("x") as log:
        while True:
            current = snapshot()
            assert current[NAMES[3]] == initial[NAMES[3]]
            assert all(
                current[name]["command"] == initial[name]["command"]
                and current[name]["image"] == initial[name]["image"]
                for name in NAMES
            )
            log.write(json.dumps({**telemetry(), "containers": current}) + "\n")
            log.flush()
            if all(
                current[name]["running"] and current[name]["health"] == "healthy"
                for name in NAMES[:3]
            ):
                break
            if time.monotonic() > deadline:
                raise TimeoutError("Original engines did not become healthy")
            time.sleep(5)
    hashes = json.loads((directory / "canonical-hashes-before.json").read_text())
    assert all(
        hashlib.sha256(Path(path).read_bytes()).hexdigest() == value
        for path, value in hashes.items()
    )
    save(directory / "after.json", current)
    kernel = subprocess.run(
        [
            "journalctl",
            "-k",
            "-b",
            "--no-pager",
            "-o",
            "short-iso",
            "--since",
            status["since"],
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
            "returncode": kernel.returncode,
            "stdout": kernel.stdout,
            "stderr": kernel.stderr,
        },
    )
    save(
        directory / "status.json",
        {
            "stage": "incomplete_restored",
            "since": status["since"],
            "until": datetime.datetime.now().astimezone().isoformat(),
            "canonical_unchanged": True,
            "original_images_commands_restored": True,
            "controller_failed_during_restore": True,
            "recovery": "Existing Docker restart policy; readiness awaited separately",
        },
    )
    print("All original engines healthy; canonical files unchanged.", flush=True)


if __name__ == "__main__":
    main()
