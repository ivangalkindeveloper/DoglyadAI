"""Build once and roll out backend images to an explicitly inventoried fleet."""

from __future__ import annotations

import argparse
import json
import re
import shlex
import signal
import subprocess
import sys
import time
import uuid
from pathlib import Path
from urllib.parse import quote

from inference.host_profile import HostProfile

REPO = "ivangalkindeveloper/DoglyadAI"
REGISTRY = "ghcr.io/ivangalkindeveloper/doglyad-"
DIRECTORY = Path(__file__).resolve().parent


def command(
    args: list[str], *, input_text: str | None = None, timeout: int = 120
) -> str:
    result = subprocess.run(
        args, input=input_text, text=True, capture_output=True, timeout=timeout
    )
    if result.returncode:
        # Do not dump remote stderr: Docker/Compose errors can include resolved secrets.
        raise RuntimeError(
            f"{args[0]} failed (exit {result.returncode}); inspect the service locally"
        )
    return result.stdout.strip()


def github(*args: str) -> object:
    return json.loads(command(["gh", *args]))


def inventory(path: Path) -> list[dict]:
    targets = json.loads(path.read_text())["targets"]
    if not isinstance(targets, list) or not targets:
        raise ValueError("Inventory must contain a non-empty targets list")
    seen: set[tuple[str, str]] = set()
    models: set[str] = set()
    for target in targets:
        if target.get("role") not in {"development", "production", "inference"}:
            raise ValueError("Unknown inventory role")
        if "profile" in target and (
            target["role"] != "inference"
            or not isinstance(target["profile"], str)
            or not target["profile"]
        ):
            raise ValueError("Only inference targets accept a host profile path")
        host = target.get("ssh", "")
        if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.@-]*", host):
            raise ValueError("SSH targets must be aliases or user@host values")
        directory = target.get("directory", "/opt/doglyad")
        if not re.fullmatch(r"/opt/doglyad(?:/[A-Za-z0-9_-]+)*", directory):
            raise ValueError("Deployment directory must be inside /opt/doglyad")
        if (host, directory) in seen:
            raise ValueError("SSH target and deployment directory must be unique")
        if any(
            other_host == host
            and (
                directory.startswith(other_dir + "/")
                or other_dir.startswith(directory + "/")
            )
            for other_host, other_dir in seen
        ):
            raise ValueError("Deployment directories on one host must not overlap")
        seen.add((host, directory))
        if target["role"] == "inference" and "profile" in target:
            if any(key in target for key in ("model", "models", "profile_fingerprint")):
                raise ValueError(
                    "Profile targets must not duplicate their model configuration"
                )
            profile = HostProfile.load(path.parent / target["profile"])
            if target.get("architecture", profile.architecture) != profile.architecture:
                raise ValueError("Inventory architecture conflicts with host profile")
            target["architecture"] = profile.architecture
            target["models"] = profile.models
            target["profile_fingerprint"] = profile.fingerprint
        elif "models" in target or "profile_fingerprint" in target:
            raise ValueError("Model lists must come from a host profile")
        architecture = target.get("architecture", "amd64")
        if architecture not in {"amd64", "arm64"}:
            raise ValueError("Unsupported deployment architecture")
        if target["role"] != "inference" and architecture != "amd64":
            raise ValueError("Main backend images support amd64 only")
        if target["role"] == "inference":
            for model in target.get("models", {target.get("model"): "vllm"}):
                if not isinstance(model, str) or not model or model in models:
                    raise ValueError("Inference targets require unique model IDs")
                models.add(model)
    for role in ("development", "production"):
        if sum(t["role"] == role for t in targets) != 1:
            raise ValueError(f"Full inventory requires exactly one {role} VM")
    if not models:
        raise ValueError("Full inventory requires at least one inference VM")
    return sorted(
        targets,
        key=lambda t: {"inference": 0, "development": 1, "production": 2}[t["role"]],
    )


def remote(target: dict, action: str, release: str, **values: object) -> dict:
    if action == "stage":
        values["storage_script"] = (
            DIRECTORY / "prepare_backend_storage.py"
        ).read_text()
    payload = json.dumps(dict(action=action, release=release, target=target, **values))
    invocation = "python3 - " + shlex.quote(payload)
    output = command(
        [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=10",
            target["ssh"],
            invocation,
        ],
        input_text=(DIRECTORY / "update_remote.py").read_text(),
        timeout=900,
    )
    return json.loads(output)


def build(ref: str, timeout: int) -> tuple[str, str]:
    sha = github("api", f"repos/{REPO}/commits/{quote(ref, safe='')}")["sha"]
    correlation = uuid.uuid4().hex

    def runs() -> list[dict]:
        return github(
            "run",
            "list",
            "--repo",
            REPO,
            "--workflow",
            "build.yml",
            "--event",
            "workflow_dispatch",
            "--limit",
            "100",
            "--json",
            "databaseId,headSha,url,displayTitle",
        )

    command(
        [
            "gh",
            "workflow",
            "run",
            "build.yml",
            "--repo",
            REPO,
            "--ref",
            ref,
            "-f",
            f"deployment_id={correlation}",
        ]
    )
    print(f"Build dispatched for {sha}", flush=True)
    deadline = time.monotonic() + timeout
    run = None
    while time.monotonic() < deadline:
        matches = [
            r for r in runs() if r["displayTitle"] == f"Backend images {correlation}"
        ]
        if len(matches) > 1:
            raise RuntimeError(
                "Concurrent matching builds: refusing ambiguous deployment"
            )
        if matches:
            run = matches[0]
            if run["headSha"] != sha:
                raise RuntimeError("Branch advanced before dispatch; no VM was updated")
            break
        time.sleep(5)
    if run is None:
        raise RuntimeError(
            "Dispatched build not found for intended SHA; no VM was updated"
        )
    print(f"Actions: {run['url']}", flush=True)
    while time.monotonic() < deadline:
        status = github(
            "run",
            "view",
            str(run["databaseId"]),
            "--repo",
            REPO,
            "--json",
            "status,conclusion,headSha,jobs",
        )
        if status["status"] == "completed":
            if (
                status["conclusion"] != "success"
                or status["headSha"] != sha
                or not {"publish (main)", "publish (inference)"}.issubset(
                    {job["name"] for job in status["jobs"]}
                )
                or any(j["conclusion"] != "success" for j in status["jobs"])
            ):
                raise RuntimeError(
                    f"All checks and image publication jobs must succeed: {run['url']}"
                )
            return sha, run["url"]
        print("Waiting for backend image build...", flush=True)
        time.sleep(15)
    raise RuntimeError(f"Build wait timed out; workflow may still run: {run['url']}")


def platform_image(service: str, sha: str, architecture: str) -> str:
    image = f"{REGISTRY}{service}:{sha}"
    manifest = json.loads(
        command(["docker", "manifest", "inspect", "--verbose", image])
    )
    entries = manifest if isinstance(manifest, list) else [manifest]
    for entry in entries:
        descriptor = entry.get("Descriptor", {})
        platform = descriptor.get("platform", {})
        digest = descriptor.get("digest", "")
        if (
            platform.get("os") == "linux"
            and platform.get("architecture") == architecture
        ):
            if re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
                return f"{REGISTRY}{service}@{digest}"
    raise RuntimeError(f"No linux/{architecture} manifest for {image}")


def image_key(target: dict) -> tuple[str, str]:
    service = "inference" if target["role"] == "inference" else "main"
    return service, target.get("architecture", "amd64")


def target_label(target: dict) -> str:
    return f"{target['ssh']}:{target.get('directory', '/opt/doglyad')}"


def rollout(
    targets: list[dict],
    release: str,
    images: dict[tuple[str, str], str],
    sha: str,
    *,
    check_inference_routes: bool = True,
) -> None:
    attempted: list[dict] = []
    try:
        for target in targets:
            attempted.append(target)  # SSH may disconnect after the remote mutation.
            result = remote(
                target, "update", release, image=images[image_key(target)], sha=sha
            )
            print(
                f"Updated {target['role']} {target_label(target)}: {result['image']}",
                flush=True,
            )
            if check_inference_routes:
                for main in targets:
                    if main["role"] != "inference":
                        remote(main, "routes", release)
    except BaseException:
        for target in reversed(attempted):
            try:
                remote(target, "rollback", release)
                print(f"Rolled back {target_label(target)}", flush=True)
            except BaseException:
                print(
                    f"ROLLBACK UNCONFIRMED: {target_label(target)}; snapshot .deploy-{release}",
                    file=sys.stderr,
                )
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--inventory", type=Path, default=DIRECTORY / "secrets" / "infrastructure.json"
    )
    parser.add_argument("--ref", default="master")
    parser.add_argument(
        "--scope",
        choices=("all", "main"),
        default="all",
        help="main updates both main environments without contacting inference VMs",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="read-only fleet preflight; no build or update",
    )
    parser.add_argument("--build-timeout", type=int, default=3600)
    args = parser.parse_args()
    all_targets = inventory(args.inventory)
    targets = (
        all_targets
        if args.scope == "all"
        else [target for target in all_targets if target["role"] != "inference"]
    )
    check_inference_routes = args.scope == "all"
    release = uuid.uuid4().hex
    prepared: list[dict] = []
    rollout_started = False
    rollout_completed = False
    try:
        for target in targets:
            result = remote(target, "check", release)
            print(
                f"Ready: {target['role']} {target_label(target)} ({result['image']})",
                flush=True,
            )
        expected_models = [
            model
            for target in all_targets
            if target["role"] == "inference"
            for model in target.get("models", {target.get("model"): "vllm"})
        ]
        if check_inference_routes:
            for target in targets:
                if target["role"] != "inference":
                    remote(target, "routes", release, models=expected_models)
        else:
            print("Main-only scope: inference availability/routes are not checked.")
        if args.check:
            print("Preflight passed. No changes made. Generation not tested.")
            return 0
        sha, url = build(args.ref, args.build_timeout)
        images = {
            (service, architecture): platform_image(service, sha, architecture)
            for service, architecture in sorted({image_key(t) for t in targets})
        }
        # Snapshot all selected targets before replacement. Persistent locks
        # also block another invocation if this process is killed or disconnected.
        for target in targets:
            prepared.append(target)
            remote(target, "prepare", release)
        for target in targets:
            remote(
                target,
                "stage",
                release,
                image=images[image_key(target)],
                models=expected_models,
            )
        rollout_started = True
        rollout(
            targets,
            release,
            images,
            sha,
            check_inference_routes=check_inference_routes,
        )
        rollout_completed = True
        print(
            f"Updated scope={args.scope}: {sha}\n{url}\nCaddy/vLLM preserved. Generation not tested."
        )
        return 0
    finally:
        for target in reversed(prepared):
            if rollout_started and not rollout_completed:
                print(
                    f"Retained recovery lock: {target_label(target)} release={release}",
                    file=sys.stderr,
                )
                continue
            try:
                remote(target, "unlock", release)
            except Exception:
                print(
                    f"Lock cleanup unconfirmed: {target_label(target)} release={release}",
                    file=sys.stderr,
                )


if __name__ == "__main__":

    def interrupted(signum: int, frame: object) -> None:
        raise KeyboardInterrupt()

    signal.signal(signal.SIGTERM, interrupted)
    try:
        sys.exit(main())
    except (Exception, KeyboardInterrupt) as error:
        print(f"Update stopped: {error}", file=sys.stderr)
        sys.exit(1)
