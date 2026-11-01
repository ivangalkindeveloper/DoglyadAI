"""Verify unchanged deployment and run a tiny structured request on each restored engine."""

from __future__ import annotations

import argparse
import json
import subprocess
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import host_helpers as host


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True)
    args = parser.parse_args()
    directory = Path(args.directory)
    conditions = json.loads((directory / "conditions.json").read_text())
    assert conditions["is_restored"]
    before, current = conditions["before"], host._snapshot()
    assert (
        before["file_sha256"] == current["file_sha256"]
        and before["boot_id"] == current["boot_id"]
    )
    report = {
        "time": datetime.now(timezone.utc).isoformat(),
        "is_configuration_unchanged": True,
        "is_boot_unchanged": True,
        "engines": [],
    }
    for old, now in zip(before["containers"], current["containers"]):
        assert (
            old["id"] == now["id"]
            and old["image"] == now["image"]
            and old["command"] == now["command"]
        )
        if old["name"] == host.BACKEND:
            assert (
                old["started_at"] == now["started_at"]
                and old["restart_count"] == now["restart_count"]
            )
            report["is_backend_unrestarted"] = True
            continue
        code = """import hashlib,json,sys,urllib.request
base='http://127.0.0.1:8000'
health=urllib.request.urlopen(base+'/health',timeout=5).status
models=json.load(urllib.request.urlopen(base+'/v1/models',timeout=5))
assert [m['id'] for m in models['data']]==[sys.argv[1]]
payload={'model':sys.argv[1],'temperature':0,'max_tokens':32,'messages':[{'role':'user','content':'Synthetic readiness test. Return JSON with status ok.'}],
 'response_format':{'type':'json_schema','json_schema':{'name':'readiness','schema':{'type':'object','properties':{'status':{'type':'string','enum':['ok']}},'required':['status'],'additionalProperties':False}}}}
req=urllib.request.Request(base+'/v1/chat/completions',data=json.dumps(payload).encode(),headers={'Content-Type':'application/json'})
answer=json.load(urllib.request.urlopen(req,timeout=120))
content=answer['choices'][0]['message']['content']
assert json.loads(content)=={'status':'ok'} and answer['choices'][0]['finish_reason']=='stop'
print(json.dumps({'health':health,'is_generation_valid':True,'usage':answer['usage'],'output_sha256':hashlib.sha256(content.encode()).hexdigest()}))
"""
        value = json.loads(
            host._command(
                [
                    "docker",
                    "exec",
                    old["name"],
                    "python3",
                    "-c",
                    code,
                    old["command"][0],
                ],
                timeout=150,
            )
        )
        report["engines"].append({"model": old["command"][0], **value})
    backend = host._inspect(host.BACKEND)
    binding = backend["NetworkSettings"]["Ports"]["8000/tcp"][0]
    private_ip = host._command(["tailscale", "ip", "-4"]).strip()
    assert binding["HostIp"] == private_ip
    client = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    request = urllib.request.Request(
        f"http://{private_ip}:{binding['HostPort']}/v1/generation",
        data=b"{}",
        headers={"Content-Type": "application/json"},
    )
    try:
        report["unauthenticated_status"] = client.open(request, timeout=10).status
    except urllib.error.HTTPError as error:
        report["unauthenticated_status"] = error.code
    assert report["unauthenticated_status"] == 401
    journal = subprocess.run(
        ["journalctl", "-k", "-b", "--no-pager"],
        text=True,
        capture_output=True,
        timeout=30,
    )
    assert journal.returncode == 0 and len(journal.stdout.splitlines()) > 100
    recent = host._command(
        ["journalctl", "-k", "-b", "--since", "2026-11-01T11:51:00+00:00", "--no-pager"]
    )
    report["kernel_events"] = [
        line
        for line in recent.splitlines()
        if any(s in line for s in ["NVRM: Xid", "oom-kill", "Out of memory"])
    ]
    report["is_kernel_log_clean"] = not report["kernel_events"]
    report["is_no_gpu_xid"] = not any(
        "NVRM: Xid" in line for line in report["kernel_events"]
    )
    report["is_no_linux_oom_kill"] = not any(
        "oom-kill" in line or "Out of memory: Killed process" in line
        for line in report["kernel_events"]
    )
    report["running_containers"] = host._command(
        ["docker", "ps", "--format", "{{.Names}}"]
    ).splitlines()
    assert not any(
        n.startswith("doglyad-eval442-") for n in report["running_containers"]
    )
    assert (
        len([n for n in report["running_containers"] if n.startswith("doglyad-dgx-")])
        == 4
    )
    report["is_runtime_restored"] = True
    (directory / "restoration.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))
    if not report["is_kernel_log_clean"]:
        raise SystemExit(
            "Runtime restored, but kernel-log verification failed; see restoration.json"
        )


if __name__ == "__main__":
    main()
