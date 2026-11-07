"""Read-only readiness checks after applying N-gram and finishing the load test."""

from __future__ import annotations

import fcntl
import json
from pathlib import Path
import subprocess
import time

from observe import NAMES, ROOT, call, healthy, idle, save, snapshot, telemetry


def main() -> None:
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    before = json.loads((ROOT / "deployment-after.json").read_text())
    original = json.loads((ROOT / "deployment-before.json").read_text())
    for name in NAMES[:3]:
        healthy(name)
        idle(name)
    after = snapshot()
    rows = {}
    for name in NAMES:
        rows[name] = {
            field: before[name][field] == after[name][field]
            for field in ["id", "image", "command", "restart_policy"]
        }
        rows[name]["running"] = after[name]["running"]
    code = """import json,urllib.request,urllib.error
result={}
for path in ['/v1/generation','/v1/generation/stream']:
 request=urllib.request.Request('http://127.0.0.1:8000'+path,data=b'{}',headers={'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(request,timeout=10) as response:
   result[path]=response.status
 except urllib.error.HTTPError as error:
  result[path]=error.code
print(json.dumps(result))"""
    auth = json.loads(call(["docker", "exec", NAMES[3], "python3", "-c", code]))
    code = """import json,os,urllib.request
routes=json.loads(os.environ['VLLM_ENDPOINTS'])
opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
result={}
for model,url in routes.items():
 with opener.open(url.rstrip('/')+'/health',timeout=10) as response:
  status=response.status
 with opener.open(url.rstrip('/')+'/v1/models',timeout=10) as response:
  models=json.load(response)['data']
 result[model]={'health_status':status,'configured_model_present':any(row['id']==model for row in models)}
print(json.dumps(result))"""
    routes = json.loads(
        call(["docker", "exec", NAMES[3], "python3", "-c", code], timeout=90)
    )
    boot = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
    previous_boot = json.loads((ROOT / "host-before.json").read_text())["boot_id"]
    containers = call(["docker", "ps", "-a", "--format", "{{.Names}}"])
    kernel = subprocess.run(
        [
            "journalctl",
            "-k",
            "-b",
            "--no-pager",
            "-o",
            "short-iso",
            "--since",
            json.loads((ROOT / "host-before.json").read_text())["since"],
            "--grep",
            "NVRM: Xid|Out of memory|oom-kill|GPU has fallen off|NV_ERR_NO_MEMORY",
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )
    save(
        ROOT / "kernel-error-query.json",
        {
            "returncode": kernel.returncode,
            "stdout": kernel.stdout,
            "stderr": kernel.stderr,
        },
    )
    result = {
        "unix": time.time(),
        "containers": rows,
        "backend_never_restarted": original[NAMES[3]] == after[NAMES[3]],
        "unauthenticated_api_status": auth,
        "backend_engine_routes": routes,
        "same_boot": boot == previous_boot,
        "boot_id": boot,
        "only_expected_containers": set(containers.splitlines()) == set(NAMES),
        "host": telemetry(),
    }
    save(ROOT / "runtime-final.json", after)
    save(ROOT / "verification.json", result)
    assert all(all(checks.values()) for checks in rows.values())
    assert all(status == 401 for status in auth.values())
    assert len(routes) == 3 and all(
        r["health_status"] == 200 and r["configured_model_present"]
        for r in routes.values()
    )
    assert result["backend_never_restarted"]
    assert result["same_boot"]
    assert result["only_expected_containers"]
    print(
        "N-gram engines ready and idle; App Check rejects both unauthenticated routes."
    )


if __name__ == "__main__":
    main()
