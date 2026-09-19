"""Sent over SSH stdin by update_infrastructure.py; no installation required."""

from __future__ import annotations

import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path("/opt/doglyad")


def run(*args: str, timeout: int = 120) -> str:
    result = subprocess.run(args, text=True, capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"{args[0]} failed, exit {result.returncode}")
    return result.stdout.strip()


def compose(*args: str) -> str:
    return run("docker", "compose", "-f", "docker-compose.yml", *args)


def container(service: str) -> dict:
    cid = compose("ps", "-q", service)
    if not cid or "\n" in cid:
        raise RuntimeError(f"Expected one running {service} container")
    return json.loads(run("docker", "inspect", cid))[0]


def values() -> dict[str, str]:
    # Match the simple machine .env contract; do not execute/source this file.
    result = {}
    for line in Path(".env").read_text().splitlines():
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            if key in result:
                raise RuntimeError("Duplicate machine configuration key")
            result[key] = value.strip().strip("\"'")
    return result


def http(url: str, post: bool = False) -> None:
    args = [
        "curl",
        "--noproxy",
        "*",
        "--silent",
        "--output",
        "/dev/null",
        "--write-out",
        "%{http_code}",
        "--connect-timeout",
        "5",
        "--max-time",
        "10",
    ]
    if post:
        args += ["-H", "Content-Type: application/json", "--data", "{}"]
    if run(*args, url, timeout=15) != "401":
        raise RuntimeError("Protected endpoint did not return 401")


def check(target: dict) -> dict:
    cfg = values()
    compose("config", "--quiet")
    inference = target["role"] == "inference"
    service = "backend_inference" if inference else "backend_main"
    companion = container("vllm" if inference else "caddy")
    backend = container(service)
    if not backend["State"]["Running"] or not companion["State"]["Running"]:
        raise RuntimeError("Container not running")
    if inference:
        if cfg.get("SERVED_MODEL_ID") != target["model"]:
            raise RuntimeError("Served model does not match inventory")
        if cfg.get("INFERENCE_BACKEND_BIND") != run("tailscale", "ip", "-4"):
            raise RuntimeError(
                "Inference is not bound to the current Tailscale address"
            )
        if companion["State"].get("Health", {}).get("Status") != "healthy":
            raise RuntimeError("vLLM is not healthy")
        http(
            f"http://{cfg['INFERENCE_BACKEND_BIND']}:{cfg.get('INFERENCE_BACKEND_PORT', '8100')}/v1/generation",
            True,
        )
    else:
        if cfg.get("ENV_FILE") != f"secrets/.env.{target['role']}":
            raise RuntimeError("Main environment does not match inventory")
        domain = cfg.get("DOMAIN", "")
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]*", domain):
            raise RuntimeError("Invalid public domain")
        http(f"https://{domain}/v1/application_config")
        http(f"https://{domain}/v1/ultrasound/generate_report", True)
    return {
        "image": backend["Image"],
        "container": backend["Id"],
        "companion": companion["Id"],
        "restarts": backend["RestartCount"],
    }


ROUTES = """
import json, os
from urllib.parse import urlsplit
from urllib.request import ProxyHandler, build_opener, Request
from urllib.error import HTTPError
from app.core.variables import variables
mapping = json.load(open(variables.inference_endpoints_path))
expected = json.loads(__import__('sys').argv[1])
assert not expected or set(mapping) <= set(expected), 'Inventory omits mapped models'
for url in mapping.values():
    base = url.split('/v1/', 1)[0].rstrip('/')
    if base.endswith('/v1'): base = base[:-3]
    assert urlsplit(base).scheme == 'http', 'Expected private HTTP inference URL'
    try:
        build_opener(ProxyHandler({})).open(Request(base + '/v1/generation', data=b'{}', headers={'Content-Type':'application/json'}), timeout=10)
    except HTTPError as error:
        assert error.code == 401, 'Unexpected inference response'
    else:
        raise RuntimeError('Inference accepted unauthenticated request')
"""


def wait_ready(target: dict, image_id: str, companion: str) -> dict:
    for attempt in range(12):
        try:
            first = check(target)
            time.sleep(3)
            second = check(target)
            if (
                first["container"] == second["container"]
                and second["image"] == image_id
                and second["companion"] == companion
                and first["restarts"] == second["restarts"]
            ):
                return second
        except (RuntimeError, subprocess.TimeoutExpired):
            pass
        time.sleep(2)
    raise RuntimeError("Container did not pass readiness/image/stability checks")


def main(payload: dict) -> dict:
    os.chdir(ROOT)
    # The machine file, not the SSH login environment, selects the image.
    os.environ.pop("TAG", None)
    action, release, target = payload["action"], payload["release"], payload["target"]
    if not re.fullmatch(r"[0-9a-f]{32}", release):
        raise ValueError("Invalid release identifier")
    service = "backend_inference" if target["role"] == "inference" else "backend_main"
    snapshot = Path(f".deploy-{release}")
    lock = Path(".infrastructure-update-lock")
    if action == "check":
        if lock.exists():
            raise RuntimeError("Deployment lock exists; inspect previous rollout")
        return check(target)
    if action == "routes":
        compose(
            "exec",
            "-T",
            "backend_main",
            "python",
            "-c",
            ROUTES,
            json.dumps(payload.get("models", [])),
        )
        return {"routes": "passed"}
    # Advisory lock serializes remote operations even if a local SSH client dies.
    with Path(".infrastructure-operation-lock").open("a") as operation:
        fcntl.flock(operation, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if action == "prepare":
            os.mkdir(lock, 0o700)
            (lock / "owner").write_text(release)
            state = check(target)
            snapshot.mkdir(mode=0o700)
            shutil.copy2(".env", snapshot / "env")
            shutil.copy2("docker-compose.yml", snapshot / "compose")
            (snapshot / "state.json").write_text(json.dumps(state))
            return state
        if not lock.exists() and action == "unlock":
            return {"lock": "absent"}
        if (lock / "owner").read_text() != release:
            raise RuntimeError("Deployment lock belongs to another release")
        if action == "unlock":
            (lock / "owner").unlink()
            lock.rmdir()
            return {"lock": "released"}
        state = json.loads((snapshot / "state.json").read_text())
        if action == "stage":
            image = payload["image"]
            if not re.fullmatch(
                r"ghcr.io/ivangalkindeveloper/doglyad-(main|inference)@sha256:[0-9a-f]{64}",
                image,
            ):
                raise ValueError("Invalid deployment image")
            run("docker", "pull", image, timeout=600)
            if service == "backend_main":
                # Validate the new model catalog against this VM's existing mappings.
                validation = """
import json, sys
models = json.load(open('/app/config/' + sys.argv[1] + '/ultrasound_examination_neural_models.json'))
mapping = json.load(open('/app/secrets/inference_endpoints.json'))
assert set(mapping) <= set(json.loads(sys.argv[2])), 'Inventory omits mapped models'
def visit(value):
    if isinstance(value, dict):
        if value.get('accessibility') == 'available' and 'id' in value:
            assert value['id'] in mapping, 'Missing model endpoint'
        for child in value.values(): visit(child)
    elif isinstance(value, list):
        for child in value: visit(child)
visit(models)
"""
                run(
                    "docker",
                    "run",
                    "--rm",
                    "--network",
                    "none",
                    "--entrypoint",
                    "python",
                    "-v",
                    f"{ROOT}/secrets:/app/secrets:ro",
                    image,
                    "-c",
                    validation,
                    target["role"],
                    json.dumps(payload["models"]),
                )
            return {"staged": image}
        if action == "update":
            if (
                Path("docker-compose.yml").read_bytes()
                != (snapshot / "compose").read_bytes()
            ):
                raise RuntimeError("Compose changed during rollout")
            image, sha = payload["image"], payload["sha"]
            if not re.fullmatch(r"[0-9a-f]{40}", sha):
                raise ValueError("Invalid commit SHA")
            image_id = json.loads(run("docker", "image", "inspect", image))[0]["Id"]
            tag = sha + "@" + image.split("@", 1)[1]
            lines = Path(".env").read_text().splitlines()
            lines = [line for line in lines if not line.startswith("TAG=")]
            temporary = snapshot / "new-env"
            temporary.write_text("\n".join([*lines, f"TAG={tag}", ""]))
            os.chmod(temporary, 0o600)
            os.replace(temporary, ".env")
            compose("config", "--quiet")
            compose(
                "up", "-d", "--no-deps", "--pull", "never", "--force-recreate", service
            )
            return wait_ready(target, image_id, state["companion"])
        if action == "rollback":
            shutil.copy2(snapshot / "env", ".env")
            # Use the recorded local image ID, even if the old tag has moved.
            override = snapshot / "rollback.json"
            override.write_text(
                json.dumps({"services": {service: {"image": state["image"]}}})
            )
            run(
                "docker",
                "compose",
                "-f",
                "docker-compose.yml",
                "-f",
                str(override),
                "up",
                "-d",
                "--no-deps",
                "--pull",
                "never",
                "--force-recreate",
                service,
            )
            return wait_ready(target, state["image"], state["companion"])
        raise ValueError("Unknown remote action")


if __name__ == "__main__":
    try:
        print(json.dumps(main(json.loads(sys.argv[1]))))
    except Exception:
        # Avoid leaking configuration or endpoint URLs in tracebacks.
        print(
            "Remote deployment operation failed; inspect snapshots and container state",
            file=sys.stderr,
        )
        sys.exit(1)
