"""Read-only verification that the original DGX services are restored."""

import json
from pathlib import Path
import subprocess

from run_trial import NAMES, TEMP, _activity, _inspect, _snapshot

root = Path(__file__).resolve().parent
initial = json.loads((root / "runtime-initial.json").read_text())
snapshot = _snapshot()
checks = {}
for index, name in enumerate(NAMES):
    original = initial[name]
    actual = snapshot[name]
    checks[name] = {
        "same_container": actual["id"] == original["Id"],
        "same_image": actual["image"] == original["Image"],
        "same_command": actual["command"] == original["command"],
        "same_restart_policy": _inspect(name)["HostConfig"]["RestartPolicy"]
        == original["restart"],
        "running": actual["running"],
        "healthy": actual["health"] == "healthy" if index < 3 else True,
    }
    if index:
        checks[name]["not_restarted"] = (
            actual["started"] == original["state"]["StartedAt"]
        )
activity = _activity()
before = json.loads((root / "vllm-4b-baseline/activity.json").read_text())["before"]
idle_models_unchanged = all(activity[name] == before[name] for name in NAMES[1:3])
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
    "idle_model_counters_unchanged": idle_models_unchanged,
    "activity": activity,
    "without_app_check_status": authentication,
    "running_containers": running,
    "temporary_engine_absent": TEMP not in running,
    "uptime_seconds": float(Path("/proc/uptime").read_text().split()[0]),
}
(root / "restoration.json").write_text(json.dumps(result, indent=2) + "\n")
assert all(all(values.values()) for values in checks.values()), checks
assert idle_models_unchanged
assert all(value == 401 for value in authentication.values()), authentication
assert TEMP not in running
print("Original containers, images, commands, queues and App Check verified.")
