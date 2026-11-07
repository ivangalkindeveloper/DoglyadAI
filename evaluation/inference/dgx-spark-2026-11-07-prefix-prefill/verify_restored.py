"""Verify original engine settings, private routing, and App Check after testing."""

from __future__ import annotations

import fcntl
import hashlib
import json
from pathlib import Path
import subprocess
import time

from observe import NAMES, ROOT, call, idle, save, snapshot, telemetry


def main() -> None:
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    before = json.loads((ROOT / "prefill-live/before.json").read_text())
    after = snapshot()
    hashes = json.loads(
        (ROOT / "prefill-live/canonical-hashes-before.json").read_text()
    )
    containers = {
        name: {
            "original_image": after[name]["image"] == before[name]["image"],
            "original_command": after[name]["command"] == before[name]["command"],
            "original_restart_policy": after[name]["restart_policy"]
            == before[name]["restart_policy"],
            "running": after[name]["running"],
            **(
                {"healthy": after[name]["health"] == "healthy"}
                if name in NAMES[:3]
                else {}
            ),
        }
        for name in NAMES
    }
    assert all(all(values.values()) for values in containers.values())
    for name in NAMES[:3]:
        idle(name)
    code = """import json,os,urllib.request,urllib.error
opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
auth={}
for path in ['/v1/generation','/v1/generation/stream']:
 request=urllib.request.Request('http://127.0.0.1:8000'+path,data=b'{}',headers={'Content-Type':'application/json'})
 try:
  with opener.open(request,timeout=10) as response:
   auth[path]=response.status
 except urllib.error.HTTPError as error:
  auth[path]=error.code
routes={}
for model,url in json.loads(os.environ['VLLM_ENDPOINTS']).items():
 with opener.open(url.rstrip('/')+'/health',timeout=10) as response:
  status=response.status
 with opener.open(url.rstrip('/')+'/v1/models',timeout=10) as response:
  models=json.load(response)['data']
 routes[model]={'health_status':status,'configured_model_present':any(row['id']==model for row in models)}
print(json.dumps({'unauthenticated_api_status':auth,'backend_engine_routes':routes}))"""
    checks = json.loads(
        call(["docker", "exec", NAMES[3], "python3", "-c", code], timeout=90)
    )
    result = {
        "unix": time.time(),
        "containers": containers,
        "backend_unchanged": before[NAMES[3]] == after[NAMES[3]],
        "canonical_unchanged": all(
            hashlib.sha256(Path(path).read_bytes()).hexdigest() == value
            for path, value in hashes.items()
        ),
        **checks,
        "host": telemetry(),
    }
    status = json.loads((ROOT / "prefill-live/status.json").read_text())
    kernel = subprocess.run(
        [
            "journalctl",
            "-k",
            "-b",
            "--no-pager",
            "-o",
            "short-iso",
            "--since",
            status["until"],
            "--grep",
            "NVRM: Xid|Out of memory|oom-kill|GPU has fallen off|NV_ERR_NO_MEMORY",
        ],
        text=True,
        capture_output=True,
        timeout=30,
    )
    result["kernel_since_restore"] = {
        "returncode": kernel.returncode,
        "stdout": kernel.stdout,
        "stderr": kernel.stderr,
    }
    save(ROOT / "runtime-final.json", after)
    save(ROOT / "restoration-verification.json", result)
    assert result["backend_unchanged"] and result["canonical_unchanged"]
    assert all(value == 401 for value in checks["unauthenticated_api_status"].values())
    routes = checks["backend_engine_routes"]
    assert len(routes) == 3 and all(
        row["health_status"] == 200 and row["configured_model_present"]
        for row in routes.values()
    )
    print("Original settings restored; three routes ready; App Check returns 401.")


if __name__ == "__main__":
    main()
