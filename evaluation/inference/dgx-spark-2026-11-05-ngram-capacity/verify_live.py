"""Check both adapter methods under the selected real configuration."""

import fcntl
import json
from pathlib import Path
import subprocess
import time

from apply_selected import readiness
from observe import NAMES, call, healthy, idle, save, snapshot, telemetry

ROOT = Path(__file__).resolve().parent


def main():
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    assert (
        json.loads((ROOT / "deployment/verification.json").read_text())["status"]
        == "applied"
    )
    before = snapshot()
    for name in NAMES[:3]:
        healthy(name)
        idle(name)
    target = "/tmp/doglyad-capacity-smoke-20261105"
    call(["docker", "exec", NAMES[3], "mkdir", "-p", target])
    for name in [
        "service_smoke.py",
        "cases-4b.json",
        "cases-15-4b.json",
        "cases-27b.json",
    ]:
        call(["docker", "cp", str(ROOT / name), NAMES[3] + ":" + target + "/" + name])
    result = subprocess.run(
        [
            "docker",
            "exec",
            NAMES[3],
            "env",
            "PYTHONPATH=/app",
            "python3",
            target + "/service_smoke.py",
            target,
        ],
        capture_output=True,
        text=True,
        timeout=180,
    )
    save(
        ROOT / "service-smoke-process.json",
        {"exit_code": result.returncode, "stderr": result.stderr},
    )
    (ROOT / "service-smoke.json").write_text(result.stdout)
    result.check_returncode()
    value = json.loads(result.stdout)
    assert value["api_capacity_per_model"] == 8 and len(value["requests"]) == 24
    assert all(
        row.get("schema_valid") and row["seconds"] < 120 for row in value["requests"]
    )
    for name in NAMES[:3]:
        healthy(name)
        idle(name)
    assert snapshot() == before
    since = json.loads((ROOT / "baseline/status.json").read_text())["since"]
    kernel = subprocess.run(
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
        ROOT / "kernel-final.json",
        {
            "returncode": kernel.returncode,
            "stdout": kernel.stdout,
            "stderr": kernel.stderr,
        },
    )
    assert (
        kernel.returncode == 1
        and not kernel.stderr
        and kernel.stdout.strip() == "-- No entries --"
    )
    boot = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
    earlier = json.loads(
        Path("/var/tmp/doglyad-ngram-rollout-20261105/host-before.json").read_text()
    )["boot_id"]
    assert boot == earlier
    running = call(["docker", "ps", "--format", "{{.Names}}"])
    assert set(running.splitlines()) == set(NAMES)
    save(
        ROOT / "final-verification.json",
        {
            "unix": time.time(),
            "status": "ready",
            "same_boot_as_prior_ngram_rollout": True,
            "only_expected_four_running_containers": True,
            "containers": snapshot(),
            "readiness": readiness(),
            "host": telemetry(),
            "adapter_generate_requests": sum(
                r["method"] == "generate" for r in value["requests"]
            ),
            "adapter_stream_requests": sum(
                r["method"] == "stream" for r in value["requests"]
            ),
            "adapter_full_schema_valid_answers": 24,
            "authenticated_client_request_tested": False,
        },
    )
    print(
        "24 adapter requests passed; four containers ready, no new matching kernel errors, no reboot."
    )


if __name__ == "__main__":
    main()
