"""Read-only runtime checks plus one synthetic generation on the restored model."""

from __future__ import annotations

import argparse
import json
import subprocess
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True)
    args = parser.parse_args()
    directory = Path(args.directory)
    conditions = json.loads((directory / "conditions.json").read_text())
    assert conditions["is_restored"]
    before, after = conditions["before"], conditions["after"]
    assert before["boot_id"] == after["boot_id"]
    assert before["file_sha256"] == after["file_sha256"]
    checks = {
        "time": datetime.now(timezone.utc).isoformat(),
        "is_boot_unchanged": True,
        "is_configuration_unchanged": True,
        "engines": [],
    }
    for old, current in zip(before["containers"], after["containers"]):
        assert (
            old["id"] == current["id"]
            and old["command"] == current["command"]
            and old["image"] == current["image"]
        )
        if old["name"] != "doglyad-dgx-vllm_medgemma_4b-1":
            assert (
                old["started_at"] == current["started_at"]
                and old["restart_count"] == current["restart_count"]
            )
        if "vllm_" not in old["name"]:
            continue
        code = """import json, urllib.request
health=urllib.request.urlopen('http://127.0.0.1:8000/health',timeout=5).status
models=json.load(urllib.request.urlopen('http://127.0.0.1:8000/v1/models',timeout=5))
print(json.dumps({'health':health,'models':[m['id'] for m in models['data']]}))
"""
        result = subprocess.check_output(
            ["docker", "exec", old["name"], "python3", "-c", code],
            text=True,
            timeout=20,
        )
        parsed = json.loads(result)
        assert parsed["health"] == 200
        assert parsed["models"] == [old["command"][0]]
        checks["engines"].append({"container": old["name"], **parsed})
    code = """import hashlib, json, urllib.request
payload={'model':'google/medgemma-4b-it','temperature':0,'max_tokens':32,
 'messages':[{'role':'user','content':'Synthetic readiness test. Return the JSON object with status set to ok.'}],
 'response_format':{'type':'json_schema','json_schema':{'name':'readiness','schema':{'type':'object',
 'properties':{'status':{'type':'string','enum':['ok']}},'required':['status'],'additionalProperties':False}}}}
req=urllib.request.Request('http://127.0.0.1:8000/v1/chat/completions',data=json.dumps(payload).encode(),headers={'Content-Type':'application/json'})
response=json.load(urllib.request.urlopen(req,timeout=120))
text=response['choices'][0]['message']['content']
assert json.loads(text)=={'status':'ok'}
assert response['choices'][0]['finish_reason']=='stop'
print(json.dumps({'is_valid':True,'usage':response['usage'],'output_sha256':hashlib.sha256(text.encode()).hexdigest()}))
"""
    checks["restored_generation"] = json.loads(
        subprocess.check_output(
            ["docker", "exec", "doglyad-dgx-vllm_medgemma_4b-1", "python3", "-c", code],
            text=True,
            timeout=150,
        )
    )
    backend = json.loads(
        subprocess.check_output(
            ["docker", "inspect", "doglyad-dgx-backend_inference-1"], text=True
        )
    )[0]
    binding = backend["NetworkSettings"]["Ports"]["8000/tcp"][0]
    private_ip = subprocess.check_output(["tailscale", "ip", "-4"], text=True).strip()
    assert binding["HostIp"] == private_ip
    request = urllib.request.Request(
        f"http://{private_ip}:{binding['HostPort']}/v1/generation",
        data=b"{}",
        headers={"Content-Type": "application/json"},
    )
    try:
        checks["unauthenticated_http_status"] = urllib.request.urlopen(
            request, timeout=10
        ).status
    except urllib.error.HTTPError as error:
        checks["unauthenticated_http_status"] = error.code
    assert checks["unauthenticated_http_status"] == 401
    journal = subprocess.run(
        ["journalctl", "-k", "-b", "--no-pager"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert journal.returncode == 0 and len(journal.stdout.splitlines()) > 100
    recent = subprocess.run(
        [
            "journalctl",
            "-k",
            "-b",
            "--since",
            "2026-11-01T01:18:00+00:00",
            "--no-pager",
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert recent.returncode == 0
    checks["kernel_events"] = [
        line
        for line in recent.stdout.splitlines()
        if any(x in line for x in ["NVRM: Xid", "oom-kill", "Out of memory"])
    ]
    assert not checks["kernel_events"]
    checks["is_kernel_log_readable"] = True
    names = subprocess.check_output(
        ["docker", "ps", "--format", "{{.Names}}"], text=True
    ).splitlines()
    assert "doglyad-evaluation-medgemma-4b" not in names
    checks["running_project_containers"] = [
        n for n in names if n.startswith("doglyad-dgx-")
    ]
    assert len(checks["running_project_containers"]) == 4
    (directory / "restoration.json").write_text(json.dumps(checks, indent=2))
    print(json.dumps(checks, indent=2))


if __name__ == "__main__":
    main()
