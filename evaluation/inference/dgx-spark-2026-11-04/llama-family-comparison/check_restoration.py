"""Verify that all original DGX services survived the two-model comparison."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import time

from run_trial import NAMES, TEMP, _activity, _inspect, _snapshot


def main() -> None:
    root = Path(__file__).resolve().parent
    initial = json.loads((root / "runtime-initial.json").read_text())
    deadline = time.monotonic() + 120
    while any(
        _inspect(name)["State"].get("Health", {}).get("Status") != "healthy"
        for name in NAMES[:3]
    ):
        assert time.monotonic() < deadline, (
            "Docker health checks did not become healthy"
        )
        time.sleep(5)
    snapshot = _snapshot()
    checks = {}
    for index, name in enumerate(NAMES):
        original = initial[name]
        actual = snapshot[name]
        checks[name] = {
            "is_same_container": actual["id"] == original["id"],
            "is_same_image": actual["image"] == original["image"],
            "is_same_command": actual["command"] == original["command"],
            "is_same_restart_policy": _inspect(name)["HostConfig"]["RestartPolicy"]
            == original["restart_policy"],
            "is_running": actual["running"],
            "is_healthy": actual["health"] == "healthy" if index < 3 else True,
        }
        if index in (0, 3):
            checks[name]["is_not_restarted"] = actual["started"] == original["started"]
    activity = _activity()
    before = json.loads((root / "activity-initial.json").read_text())
    is_idle_4b_unchanged = activity[NAMES[0]] == before[NAMES[0]]
    code = """import json,urllib.request,urllib.error
result={}
for path in ['/v1/generation','/v1/generation/stream']:
 req=urllib.request.Request('http://127.0.0.1:8000'+path,data=b'{}',headers={'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(req,timeout=10) as response: result[path]=response.status
 except urllib.error.HTTPError as error: result[path]=error.code
print(json.dumps(result))
"""
    authentication = json.loads(
        subprocess.check_output(["docker", "exec", NAMES[-1], "python3", "-c", code])
    )
    running = subprocess.check_output(
        ["docker", "ps", "--format", "{{.Names}}"], text=True
    ).splitlines()
    result = {
        "snapshot": snapshot,
        "checks": checks,
        "is_idle_4b_unchanged": is_idle_4b_unchanged,
        "activity": activity,
        "without_app_check_status": authentication,
        "running_containers": running,
        "is_temporary_engine_absent": TEMP not in running,
    }
    (root / "restoration.json").write_text(json.dumps(result, indent=2) + "\n")
    assert all(all(values.values()) for values in checks.values()), checks
    assert is_idle_4b_unchanged
    assert all(value == 401 for value in authentication.values()), authentication
    assert TEMP not in running
    print("Original services, queues and App Check verified.", flush=True)


if __name__ == "__main__":
    main()
