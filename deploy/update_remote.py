"""Sent over SSH stdin by update_infrastructure.py; no installation required."""

from __future__ import annotations

import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path("/opt/doglyad")

PROFILE_CHECK = """
import json, sys
from pathlib import Path
from host_profile import HostProfile
from compose_document import compose_document
profile = HostProfile.load(Path('profile.json'))
assert profile.fingerprint == sys.argv[1], 'Host profile differs from inventory'
document = compose_document(profile)
assert json.loads(Path('docker-compose.yml').read_text()) == document, 'Generated Compose differs from profile'
print(json.dumps({model['service']: dict(
    {key: document['services'][model['service']][key] for key in ['command', 'image']},
    weightsDirectory=model.get('weightsDirectory')) for model in profile.data['models']}))
"""

ENGINE_CHECK = """
import json, sys
from urllib.request import ProxyHandler, build_opener
from app.core.variables import Variables
expected = json.loads(sys.argv[1])
variables = Variables()
routes = getattr(variables, 'model_endpoints', None)
if routes is None:
    # Older single-model images predate the host routing property.
    routes = {variables.served_model_id: str(variables.vllm_base_url).rstrip('/')}
assert routes == expected, 'Backend routes differ from host models'
opener = build_opener(ProxyHandler({}))
for model_id, base in routes.items():
    with opener.open(base + '/health', timeout=5) as response:
        assert response.status == 200
    with opener.open(base + '/v1/models', timeout=5) as response:
        document = json.load(response)
    assert {item['id'] for item in document['data']} == {model_id}, 'Engine serves another model'
"""


def run(*args: str, timeout: int = 120, input_text: str | None = None) -> str:
    result = subprocess.run(
        args, input=input_text, text=True, capture_output=True, timeout=timeout
    )
    if result.returncode:
        raise RuntimeError(f"{args[0]} failed, exit {result.returncode}")
    return result.stdout.strip()


def compose(*args: str) -> str:
    return run(*compose_command(), *args)


def compose_command() -> list[str]:
    if values().get("ENV_FILE"):
        return ["bash", "main-compose.sh"]
    return ["docker", "compose", "-f", "docker-compose.yml"]


MAIN_SERVICES = ("backend_main", "report_worker", "billing_gateway", "billing_worker")


def database_revision() -> str:
    revision = compose(
        "exec",
        "-T",
        "doglyad_database",
        "psql",
        "-U",
        "doglyad",
        "-d",
        "doglyad_database",
        "-Atc",
        "SELECT version_num FROM alembic_version",
    )
    if not re.fullmatch(r"[A-Za-z0-9_]+", revision):
        raise RuntimeError("Expected one application database migration head")
    return revision


def record_maintenance(snapshot: Path, **fields: object) -> None:
    path = snapshot / "database-maintenance.json"
    path.write_text(json.dumps(fields))
    path.chmod(0o600)


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
    architecture = {"x86_64": "amd64", "aarch64": "arm64"}.get(run("uname", "-m"))
    if architecture != target.get("architecture", "amd64"):
        raise RuntimeError("Host architecture does not match inventory")
    cfg = values()
    compose("config", "--quiet")
    inference = target["role"] == "inference"
    service = "backend_inference" if inference else "backend_main"
    backend = container(service)
    report_worker = None
    if (
        not inference
        and "report_worker" in compose("config", "--services").splitlines()
    ):
        worker = container("report_worker")
        if not worker["State"]["Running"] or worker["Image"] != backend["Image"]:
            raise RuntimeError("Report worker must run the same release as the API")
        report_worker = {
            "container": worker["Id"],
            "image": worker["Image"],
            "restarts": worker["RestartCount"],
        }
    if not backend["State"]["Running"]:
        raise RuntimeError("Container not running")
    if inference:
        models = target.get("models", {target.get("model"): "vllm"})
        if (
            not models
            or any(
                not isinstance(model, str)
                or not model
                or not isinstance(engine, str)
                or not re.fullmatch(r"[a-z][a-z0-9_-]*", engine)
                for model, engine in models.items()
            )
            or len(set(models.values())) != len(models)
        ):
            raise RuntimeError("Invalid model engine mapping")
        expected_engines = {}
        if "profile_fingerprint" in target:
            expected_engines = json.loads(
                run("python3", "-c", PROFILE_CHECK, target["profile_fingerprint"])
            )
            if set(expected_engines) != set(models.values()):
                raise RuntimeError("Profile engines differ from inventory")
        elif cfg.get("SERVED_MODEL_ID") != target["model"]:
            raise RuntimeError("Served model does not match inventory")
        if cfg.get("INFERENCE_BACKEND_BIND") != run("tailscale", "ip", "-4"):
            raise RuntimeError(
                "Inference is not bound to the current Tailscale address"
            )
        bindings = backend["HostConfig"].get("PortBindings", {})
        expected_binding = {
            "8000/tcp": [
                {
                    "HostIp": cfg["INFERENCE_BACKEND_BIND"],
                    "HostPort": cfg.get("INFERENCE_BACKEND_PORT", "8100"),
                }
            ]
        }
        if (
            bindings != expected_binding
            or backend["HostConfig"].get("NetworkMode") == "host"
        ):
            raise RuntimeError(
                "Running inference API port binding differs from private configuration"
            )
        companions = {}
        for engine in models.values():
            item = container(engine)
            if engine in expected_engines:
                expected = expected_engines[engine]
                image_id = run(
                    "docker",
                    "image",
                    "inspect",
                    "--format",
                    "{{.Id}}",
                    expected["image"],
                )
                if (
                    item["Config"]["Cmd"] != expected["command"]
                    or item["Image"] != image_id
                ):
                    raise RuntimeError(
                        "Running engine parameters/image differ from profile; apply the generated stack first"
                    )
                if expected.get("weightsDirectory"):
                    mounts = [
                        mount
                        for mount in item.get("Mounts", [])
                        if mount["Destination"] == "/model"
                    ]
                    if (
                        len(mounts) != 1
                        or mounts[0]["Type"] != "bind"
                        or mounts[0]["Source"] != expected["weightsDirectory"]
                        or mounts[0]["RW"]
                    ):
                        raise RuntimeError(
                            "Running engine weights mount differs from profile"
                        )
            if (
                not item["State"]["Running"]
                or item["State"].get("Health", {}).get("Status") != "healthy"
            ):
                raise RuntimeError("A configured vLLM engine is not healthy")
            if (
                item["HostConfig"].get("PortBindings")
                or item["HostConfig"].get("NetworkMode") == "host"
            ):
                raise RuntimeError("vLLM engines must not publish ports")
            companions[engine] = {
                "id": item["Id"],
                "image": item["Image"],
                "restarts": item["RestartCount"],
            }
        routes = {model: f"http://{engine}:8000" for model, engine in models.items()}
        run(
            "docker",
            "exec",
            backend["Id"],
            "python",
            "-c",
            ENGINE_CHECK,
            json.dumps(routes),
            timeout=max(120, 15 * len(models)),
        )
        http(
            f"http://{cfg['INFERENCE_BACKEND_BIND']}:{cfg.get('INFERENCE_BACKEND_PORT', '8100')}/v1/generation",
            True,
        )
    else:
        companion = container("caddy")
        if not companion["State"]["Running"]:
            raise RuntimeError("Caddy is not running")
        if cfg.get("ENV_FILE") != f"secrets/.env.{target['role']}":
            raise RuntimeError("Main environment does not match inventory")
        database = container("doglyad_database")
        database_image = cfg.get("DATABASE_IMAGE", "")
        if not re.fullmatch(
            r"ghcr.io/ivangalkindeveloper/doglyad-database@sha256:[0-9a-f]{64}",
            database_image,
        ):
            raise RuntimeError(
                "Main setup must pin the published database image digest"
            )
        if database["Image"] != run(
            "docker", "image", "inspect", database_image, "--format", "{{.Id}}"
        ):
            raise RuntimeError("Running database image differs from DATABASE_IMAGE")
        if (
            not database["State"]["Running"]
            or database["State"].get("Health", {}).get("Status") != "healthy"
            or database["HostConfig"].get("PortBindings")
            or database["HostConfig"].get("NetworkMode") == "host"
        ):
            raise RuntimeError("Application database must be healthy and private")
        billing_processes = {}
        for name in ("report_worker", "billing_gateway", "billing_worker"):
            process = container(name)
            if not process["State"]["Running"] or process["Image"] != backend["Image"]:
                raise RuntimeError("All main processes must run the same release")
            billing_processes[name] = {
                "container": process["Id"],
                "image": process["Image"],
                "restarts": process["RestartCount"],
            }
        for timer in ("doglyad-database-backup.timer", "doglyad-database-status.timer"):
            run("systemctl", "is-enabled", "--quiet", timer)
            run("systemctl", "is-active", "--quiet", timer)
        run("bash", "database/backup-status.sh")
        domain = cfg.get("DOMAIN", "")
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]*", domain):
            raise RuntimeError("Invalid public domain")
        http(f"https://{domain}/v1/application_config")
        http(f"https://{domain}/v1/ultrasound/report_generations", True)
        companions = {
            "caddy": {
                "id": companion["Id"],
                "image": companion["Image"],
                "restarts": companion["RestartCount"],
            },
            "database": {
                "id": database["Id"],
                "image": database["Image"],
                "restarts": database["RestartCount"],
            },
        }
    return {
        "image": backend["Image"],
        "container": backend["Id"],
        "companion": companions,
        "restarts": backend["RestartCount"],
        "report_worker": report_worker,
        **(
            {
                "billing_processes": billing_processes,
                "database_revision": database_revision(),
            }
            if not inference
            else {}
        ),
    }


ROUTES = """
import json, os
from urllib.parse import urlsplit
from urllib.request import ProxyHandler, build_opener, Request
from urllib.error import HTTPError
from app.core.configuration.variables import Variables
variables = Variables()
mapping = json.load(open(variables.inference_endpoints_path))
expected = json.loads(__import__('sys').argv[1])
assert not expected or set(mapping) <= set(expected), 'Inventory omits mapped models'
for url in mapping.values():
    base = url.split('/v1/', 1)[0].rstrip('/')
    if base.endswith('/v1'): base = base[:-3]
    assert urlsplit(base).scheme == 'http', 'Expected private HTTP inference URL'
    try:
        request = Request(base + '/v1/generation', data=b'{}', headers={'Content-Type':'application/json'})
        build_opener(ProxyHandler({})).open(request, timeout=10)
    except HTTPError as error:
        assert error.code == 401, 'Unexpected inference response'
    else:
        raise RuntimeError('Inference accepted unauthenticated request')
"""


def _companions_match(current: str | dict, expected: str | dict) -> bool:
    # Old single-engine snapshots recorded only a container ID. Keep recovery possible.
    if isinstance(expected, str) and isinstance(current, dict):
        return len(current) == 1 and next(iter(current.values()))["id"] == expected
    return current == expected


def wait_ready(
    target: dict,
    image_id: str,
    companion: str | dict,
    *,
    is_non_root_required: bool = False,
) -> dict:
    for attempt in range(12):
        try:
            first = check(target)
            time.sleep(3)
            second = check(target)
            if (
                first["container"] == second["container"]
                and second["image"] == image_id
                and _companions_match(first["companion"], companion)
                and _companions_match(second["companion"], companion)
                and first["restarts"] == second["restarts"]
                and first.get("report_worker") == second.get("report_worker")
                and first.get("billing_processes") == second.get("billing_processes")
                and first.get("database_revision") == second.get("database_revision")
            ):
                if (
                    is_non_root_required
                    and run("docker", "exec", second["container"], "id", "-u") == "0"
                ):
                    raise RuntimeError("Backend is running as root")
                return second
        except (RuntimeError, subprocess.TimeoutExpired):
            pass
        time.sleep(2)
    raise RuntimeError("Container did not pass readiness/image/stability checks")


def main(payload: dict) -> dict:
    action, release, target = payload["action"], payload["release"], payload["target"]
    root = ROOT
    if "directory" in target:
        directory = target["directory"]
        if not re.fullmatch(r"/opt/doglyad(?:/[A-Za-z0-9_-]+)*", directory):
            raise ValueError("Invalid deployment directory")
        root = Path(directory)
        if root.resolve() != root:
            raise ValueError("Deployment directory must not contain symbolic links")
    os.chdir(root)
    # The machine file, not the SSH login environment, selects the image.
    os.environ.pop("TAG", None)
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
            if service == "backend_main":
                for name in (
                    "docker-compose.database.yml",
                    "main-compose.sh",
                    "Caddyfile",
                    "database/backup.sh",
                    "database/backup-status.sh",
                    "database/backup-status.py",
                    "database/disk_backup.py",
                    "database/yandex_disk.py",
                ):
                    destination = snapshot / "main-files" / name
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(name, destination)
            if "profile_fingerprint" in target:
                shutil.copy2("profile.json", snapshot / "profile.json")
                shutil.copy2("config/server.json", snapshot / "server.json")
            (snapshot / "state.json").write_text(json.dumps(state))
            (snapshot / "target.json").write_text(json.dumps(target))
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
        if service == "backend_main" and action in {"update", "rollback"}:
            for saved in (snapshot / "main-files").rglob("*"):
                if (
                    saved.is_file()
                    and Path(saved.relative_to(snapshot / "main-files")).read_bytes()
                    != saved.read_bytes()
                ):
                    raise RuntimeError("Main stack files changed during rollout")
        if (snapshot / "target.json").exists():
            recorded = json.loads((snapshot / "target.json").read_text())
            if recorded["role"] != target["role"] or recorded.get(
                "directory", "/opt/doglyad"
            ) != target.get("directory", "/opt/doglyad"):
                raise RuntimeError("Recovery target differs from deployment snapshot")
            target = recorded
        if action in {"update", "rollback"} and "profile_fingerprint" in target:
            for current, saved in (
                ("docker-compose.yml", "compose"),
                ("profile.json", "profile.json"),
                ("config/server.json", "server.json"),
            ):
                if Path(current).read_bytes() != (snapshot / saved).read_bytes():
                    raise RuntimeError(
                        "Generated host configuration changed during rollout"
                    )
        if action == "stage":
            image = payload["image"]
            if not re.fullmatch(
                r"ghcr.io/ivangalkindeveloper/doglyad-(main|inference)@sha256:[0-9a-f]{64}",
                image,
            ):
                raise ValueError("Invalid deployment image")
            run("docker", "pull", image, timeout=600)
            # Existing installations used root-only credentials and root-owned
            # logs. Prepare bind mounts before switching to the non-root image.
            run(
                "docker",
                "run",
                "--rm",
                "-i",
                "--network",
                "none",
                "--user",
                "0:0",
                "--entrypoint",
                "python",
                "-v",
                f"{root}/secrets:/storage/secrets:rw",
                "-v",
                f"{root}/logs:/storage/logs:rw",
                image,
                "-",
                input_text=payload["storage_script"],
            )
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
                    f"{root}/secrets:/app/secrets:ro",
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
            # Spark can start with a locally verified ARM64 image. Subsequent
            # fleet releases replace that explicit image with the published digest.
            if any(line.startswith("INFERENCE_BACKEND_IMAGE=") for line in lines):
                lines = [
                    line
                    for line in lines
                    if not line.startswith("INFERENCE_BACKEND_IMAGE=")
                ]
                lines.append(f"INFERENCE_BACKEND_IMAGE={image}")
            temporary = snapshot / "new-env"
            temporary.write_text("\n".join([*lines, f"TAG={tag}", ""]))
            os.chmod(temporary, 0o600)
            os.replace(temporary, ".env")
            compose("config", "--quiet")
            if service == "backend_main":
                before = database_revision()
                if before != state["database_revision"]:
                    raise RuntimeError("Database changed after the deployment snapshot")
                record_maintenance(snapshot, phase="stopping", before=before)
                run(
                    *compose_command(),
                    "stop",
                    "--timeout",
                    "60",
                    *MAIN_SERVICES,
                    timeout=300,
                )
                run("bash", "database/backup.sh", timeout=7200)
                record_maintenance(snapshot, phase="migrating", before=before)
                run(
                    *compose_command(),
                    "run",
                    "--rm",
                    "--no-deps",
                    "database_migrate",
                    timeout=900,
                )
                after = database_revision()
                record_maintenance(
                    snapshot, phase="migrated", before=before, after=after
                )
            compose(
                "up",
                "-d",
                "--no-deps",
                "--pull",
                "never",
                "--force-recreate",
                *(MAIN_SERVICES if service == "backend_main" else (service,)),
            )
            return wait_ready(
                target, image_id, state["companion"], is_non_root_required=True
            )
        if action == "rollback":
            if (
                service == "backend_main"
                and (snapshot / "database-maintenance.json").exists()
            ):
                maintenance = json.loads(
                    (snapshot / "database-maintenance.json").read_text()
                )
                if (
                    maintenance["phase"] == "migrating"
                    or database_revision() != maintenance["before"]
                ):
                    run(
                        *compose_command(),
                        "stop",
                        "--timeout",
                        "60",
                        *MAIN_SERVICES,
                        timeout=300,
                    )
                    raise RuntimeError(
                        "Database migration changed the schema or its result is unknown; writers remain stopped. Inspect the snapshot and recover explicitly"
                    )
            shutil.copy2(snapshot / "env", ".env")
            # Use the recorded local image ID, even if the old tag has moved.
            override = snapshot / "rollback.json"
            override.write_text(
                json.dumps(
                    {
                        "services": {
                            service: {"image": state["image"]},
                            **{
                                name: {"image": process["image"]}
                                for name, process in state.get(
                                    "billing_processes", {}
                                ).items()
                            },
                        }
                    }
                )
            )
            run(
                *compose_command(),
                "-f",
                str(override),
                "up",
                "-d",
                "--no-deps",
                "--pull",
                "never",
                "--force-recreate",
                *(MAIN_SERVICES if service == "backend_main" else (service,)),
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
