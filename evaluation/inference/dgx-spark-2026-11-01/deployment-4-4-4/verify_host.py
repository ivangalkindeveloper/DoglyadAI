"""Verify deployed files, engines, private API and a real 4/4/4 generation probe."""

import json
import re
import subprocess
import urllib.error
import urllib.request
from datetime import datetime, timezone

from rollout import FILES, HOST, STAGE, run, snapshot


def api_status():
    request = urllib.request.Request(
        "http://100.110.227.68:8100/v1/generation",
        data=b"{}",
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        return opener.open(request, timeout=10).status
    except urllib.error.HTTPError as error:
        return error.code


def main():
    result = {"checks": {}}
    (STAGE / "verification.json").write_text(json.dumps(result))
    assert json.loads((STAGE / "status.json").read_text())["status"] == "started"
    for file in FILES:
        assert (HOST / file).read_bytes() == (STAGE / "generated" / file).read_bytes()
    result["checks"]["deployed_files_match"] = True
    assert (HOST / ".env").read_bytes() == (STAGE / "backup/.env").read_bytes()
    result["checks"]["machine_env_unchanged"] = True
    before = json.loads((STAGE / "before.json").read_text())
    state = snapshot()
    assert state["boot_id"] == before["boot_id"]
    rows = {r["name"].lstrip("/"): r for r in state["containers"]}
    result["engines"] = []
    result["startup_restarts"] = {name: row["restarts"] for name, row in rows.items()}
    profile = json.loads((HOST / "profile.json").read_text())
    for model in profile["models"]:
        name = "doglyad-dgx-" + model["service"] + "-1"
        row = rows[name]
        assert row["state"]["Running"] and row["state"]["Health"]["Status"] == "healthy"
        assert not row["ports"]
        command = row["command"]
        assert "--enforce-eager" not in command
        for flag, value in {
            "--max-num-seqs": 4,
            "--dtype": "bfloat16",
            "--max-model-len": 16384,
            "--kv-cache-memory-bytes": model["kvCacheMemoryBytes"],
            "--revision": model["revision"],
        }.items():
            assert command[command.index(flag) + 1] == str(value)
        assert row["image"] == next(
            r["image"] for r in before["containers"] if r["name"] == "/" + name
        )
        script = "import json,urllib.request; print(json.dumps({'health':urllib.request.urlopen('http://localhost:8000/health',timeout=10).status,'models':json.load(urllib.request.urlopen('http://localhost:8000/v1/models',timeout=10))}))"
        response = json.loads(
            run(
                ["docker", "exec", name, "python3", "-c", script],
                capture_output=True,
                text=True,
            ).stdout
        )
        assert response["health"] == 200
        assert [m["id"] for m in response["models"]["data"]] == [model["modelId"]]
        log = run(["docker", "logs", name], capture_output=True, text=True)
        lines = (log.stdout + log.stderr).splitlines()
        evidence = [
            re.sub(r"\x1b\[[0-9;]*m", "", line)
            for line in lines
            if any(
                key in line.lower()
                for key in ["compilation", "cudagraph", "graph captur", "capture cuda"]
            )
        ]
        (STAGE / (model["service"] + ".compilation.log")).write_text(
            "\n".join(evidence) + "\n"
        )
        assert any("graph capturing finished" in line.lower() for line in evidence)
        result["engines"].append(
            {
                "model": model["modelId"],
                "id": row["id"],
                "image": row["image"],
                "command": command,
                "health": "healthy",
                "restarts": row["restarts"],
                "graph_capture_confirmed": True,
            }
        )
    backend = rows["doglyad-dgx-backend_inference-1"]
    assert backend["state"]["Running"] and backend["restarts"] == 0
    assert backend["image"] == next(
        r["image"]
        for r in before["containers"]
        if r["name"].endswith("backend_inference-1")
    )
    assert backend["ports"] == {
        "8000/tcp": [{"HostIp": "100.110.227.68", "HostPort": "8100"}]
    }
    result["checks"]["api_without_token"] = api_status()
    assert result["checks"]["api_without_token"] == 401
    result["backend"] = backend
    result["probe_started_at"] = datetime.now(timezone.utc).isoformat()
    probe = subprocess.run(
        ["docker", "exec", "-i", "doglyad-dgx-backend_inference-1", "python", "-"],
        input=(STAGE / "verify_service.py").read_text(),
        text=True,
        capture_output=True,
        timeout=360,
    )
    (STAGE / "service-probe.log").write_text(probe.stdout + probe.stderr)
    assert probe.returncode == 0, "Service probe failed; inspect service-probe.log"
    service = json.loads(
        next(
            s.removeprefix("RESULT_JSON=")
            for s in probe.stdout.splitlines()
            if s.startswith("RESULT_JSON=")
        )
    )
    (STAGE / "service-results.json").write_text(json.dumps(service, indent=2))
    result["checks"]["successful_requests"] = sum(
        s["is_success"] for w in service["waves"] for s in w["samples"]
    )
    assert result["checks"]["successful_requests"] == 24
    result["after"] = snapshot()
    for row in result["after"]["containers"]:
        assert row["state"]["Running"]
        assert row["restarts"] == rows[row["name"].lstrip("/")]["restarts"]
        if "vllm_" in row["name"]:
            assert row["state"]["Health"]["Status"] == "healthy"
    result["checks"]["running_containers_after_probe"] = len(
        result["after"]["containers"]
    )
    journal = run(
        ["journalctl", "-k", "-b", "--since", before["time"], "--no-pager"],
        capture_output=True,
        text=True,
    )
    events = [
        s
        for s in journal.stdout.splitlines()
        if any(
            t in s
            for t in ["NVRM: Xid", "NV_ERR_NO_MEMORY", "oom-kill", "Out of memory"]
        )
    ]
    result["kernel_events"] = events
    result["checks"]["no_restarts_during_probe"] = True
    runtime_journal = run(
        ["journalctl", "-k", "-b", "--since", result["probe_started_at"], "--no-pager"],
        capture_output=True,
        text=True,
    )
    result["kernel_events_during_probe"] = [
        line
        for line in runtime_journal.stdout.splitlines()
        if any(
            token in line
            for token in ["NVRM: Xid", "NV_ERR_NO_MEMORY", "oom-kill", "Out of memory"]
        )
    ]
    result["checks"]["boot_unchanged"] = result["after"]["boot_id"] == before["boot_id"]
    result["checks"]["api_after_probe"] = api_status()
    assert (
        result["checks"]["boot_unchanged"]
        and result["checks"]["api_after_probe"] == 401
    )
    (STAGE / "verification.json").write_text(json.dumps(result, indent=2))
    print(json.dumps({"checks": result["checks"], "kernel_events": events}), flush=True)


if __name__ == "__main__":
    main()
