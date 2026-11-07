"""Apply a measured uniform capacity profile, with canonical-profile rollback."""

import fcntl
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

from controller import HOST, SERVICES, compose, start
from observe import NAMES, call, healthy, idle, save, snapshot, telemetry

ROOT = Path(__file__).resolve().parent
FILES = [
    "docker-compose.yml",
    "profile.json",
    "config/server.json",
    "host_profile.py",
    "compose_document.py",
    "start.py",
    "start.sh",
    ".env.example",
]


def run(args):
    subprocess.run(args, check=True, timeout=120)


def readiness():
    code = """import json,os,urllib.request,urllib.error
opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
result={'api':{},'engines':{}}
for path in ['/v1/generation','/v1/generation/stream']:
 req=urllib.request.Request('http://127.0.0.1:8000'+path,data=b'{}',headers={'Content-Type':'application/json'})
 try:
  with opener.open(req,timeout=10) as r: result['api'][path]=r.status
 except urllib.error.HTTPError as e: result['api'][path]=e.code
for model,url in json.loads(os.environ['VLLM_ENDPOINTS']).items():
 with opener.open(url.rstrip('/')+'/health',timeout=10) as r: status=r.status
 with opener.open(url.rstrip('/')+'/v1/models',timeout=10) as r: models=json.load(r)['data']
 result['engines'][model]={'status':status,'model_present':any(m['id']==model for m in models)}
with open(os.environ['CONFIG_DIR']+'/server.json') as f: result['config']=json.load(f)
print(json.dumps(result))"""
    for attempt in range(12):
        try:
            result = json.loads(
                call(["docker", "exec", NAMES[3], "python3", "-c", code], timeout=90)
            )
            assert all(v == 401 for v in result["api"].values())
            assert len(result["engines"]) == 3
            assert all(
                v["status"] == 200 and v["model_present"]
                for v in result["engines"].values()
            )
            return result
        except (subprocess.SubprocessError, AssertionError):
            if attempt == 11:
                raise
            time.sleep(3)


def main():
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    stage = ROOT / "bundle"
    decision = json.loads((ROOT / "decision.json").read_text())
    phase = ROOT / decision["profile"]
    assert json.loads((phase / "status.json").read_text())["status"] == "complete"
    evidence = json.loads((phase / "override.json").read_text())["services"]
    old = json.loads((HOST / "docker-compose.yml").read_text())
    new = json.loads((stage / "docker-compose.yml").read_text())
    old_config = json.loads((HOST / "config/server.json").read_text())
    new_config = json.loads((stage / "config/server.json").read_text())
    normalized = json.loads(json.dumps(new))
    normalized["x-doglyad-profile"] = old["x-doglyad-profile"]
    capacity = new_config["generation"]["max_concurrent_requests"]
    for service in SERVICES:
        command = new["services"][service]["command"]
        assert command == evidence[service]["command"], "Unmeasured engine command"
        assert int(command[command.index("--max-num-seqs") + 1]) == capacity
        normalized["services"][service]["command"] = old["services"][service]["command"]
    assert normalized == old, "Unexpected Compose change"
    normalized_config = json.loads(json.dumps(new_config))
    normalized_config["generation"]["max_concurrent_requests"] = old_config[
        "generation"
    ]["max_concurrent_requests"]
    assert normalized_config == old_config, "Unexpected API policy change"
    before = snapshot()
    for name in NAMES[:3]:
        healthy(name)
        idle(name)
    env_hash = hashlib.sha256((HOST / ".env").read_bytes()).hexdigest()
    boot = Path("/proc/sys/kernel/random/boot_id").read_text()
    directory = ROOT / "deployment"
    directory.mkdir(exist_ok=False)
    save(directory / "before.json", before)
    backup = directory / "backup"
    for name in FILES:
        (backup / name).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(HOST / name, backup / name)
    changed = [
        s
        for s in SERVICES
        if before["doglyad-dgx-" + s + "-1"]["command"] != new["services"][s]["command"]
    ]
    try:
        for name in FILES:
            destination = HOST / name
            temporary = destination.with_name(destination.name + ".capacity-tmp")
            assert not temporary.exists() and not destination.is_symlink()
            shutil.copy2(stage / name, temporary)
            temporary.replace(destination)
        run([*compose(), "config", "--quiet"])
        if changed:
            run([*compose(), "stop", "--timeout", "30", *reversed(changed)])
            with (directory / "startup.jsonl").open("x") as output:
                for service in changed:
                    start(service, None, output)
        if new_config != old_config:
            run([*compose(), "restart", "--timeout", "30", "backend_inference"])
        ready = readiness()
        assert ready["config"] == new_config
        after = snapshot()
        assert all(
            after[n]["running"] and after[n]["image"] == before[n]["image"]
            for n in NAMES
        )
        assert all(
            after[n]["restart_policy"] == before[n]["restart_policy"] for n in NAMES
        )
        assert all(
            after["doglyad-dgx-" + s + "-1"]["command"] == new["services"][s]["command"]
            for s in SERVICES
        )
        assert hashlib.sha256((HOST / ".env").read_bytes()).hexdigest() == env_hash
        assert Path("/proc/sys/kernel/random/boot_id").read_text() == boot
        sys.path.insert(0, str(HOST))
        from host_profile import HostProfile
        from compose_document import compose_document

        profile = HostProfile.load(HOST / "profile.json")
        assert compose_document(profile) == new
        for name in NAMES[:3]:
            healthy(name)
            idle(name)
        assert set(
            call(["docker", "ps", "--format", "{{.Names}}"]).splitlines()
        ) == set(NAMES)
        save(directory / "after.json", after)
        save(
            directory / "verification.json",
            {
                "status": "applied",
                "unix": time.time(),
                "decision": decision,
                "profile_fingerprint": profile.fingerprint,
                "canonical_matches_runtime": True,
                "images_unchanged": True,
                "env_unchanged": True,
                "same_boot_during_deployment": True,
                "engine_services_recreated": changed,
                "backend_restarted": new_config != old_config,
                "readiness": ready,
                "host": telemetry(),
                "authenticated_client_generation_tested": False,
            },
        )
        print(
            "Measured profile applied; canonical commands, routes and App Check verified.",
            flush=True,
        )
    except BaseException:
        run([*compose(), "stop", "--timeout", "30", *reversed(SERVICES)])
        for name in FILES:
            shutil.copy2(backup / name, HOST / name)
        with (directory / "rollback.jsonl").open("x") as output:
            for service in SERVICES:
                start(service, None, output)
        run([*compose(), "restart", "--timeout", "30", "backend_inference"])
        save(
            directory / "verification.json",
            {"status": "baseline_restored", "readiness": readiness()},
        )
        raise


if __name__ == "__main__":
    main()
