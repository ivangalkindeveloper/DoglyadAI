"""Build once and roll out backend images to an explicitly inventoried fleet."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shlex
import signal
import subprocess
import sys
import time
import uuid
from urllib.parse import quote

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


def inventory(path: Path) -> list[dict[str, str]]:
    targets = json.loads(path.read_text())["targets"]
    if not isinstance(targets, list) or not targets:
        raise ValueError("Inventory must contain a non-empty targets list")
    seen: set[str] = set()
    models: set[str] = set()
    for target in targets:
        if target.get("role") not in {"development", "production", "inference"}:
            raise ValueError("Unknown inventory role")
        host = target.get("ssh", "")
        if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.@-]*", host) or host in seen:
            raise ValueError("SSH targets must be unique aliases or user@host values")
        seen.add(host)
        if target["role"] == "inference":
            model = target.get("model")
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


def remote(target: dict[str, str], action: str, release: str, **values: object) -> dict:
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
                or len(status["jobs"]) != 2
                or any(j["conclusion"] != "success" for j in status["jobs"])
            ):
                raise RuntimeError(f"Both image jobs must succeed: {run['url']}")
            return sha, run["url"]
        print("Waiting for backend image build...", flush=True)
        time.sleep(15)
    raise RuntimeError(f"Build wait timed out; workflow may still run: {run['url']}")


def amd64_image(service: str, sha: str) -> str:
    image = f"{REGISTRY}{service}:{sha}"
    manifest = json.loads(
        command(["docker", "manifest", "inspect", "--verbose", image])
    )
    entries = manifest if isinstance(manifest, list) else [manifest]
    for entry in entries:
        descriptor = entry.get("Descriptor", {})
        platform = descriptor.get("platform", {})
        digest = descriptor.get("digest", "")
        if platform.get("os") == "linux" and platform.get("architecture") == "amd64":
            if re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
                return f"{REGISTRY}{service}@{digest}"
    raise RuntimeError(f"No linux/amd64 manifest for {image}")


def rollout(
    targets: list[dict[str, str]], release: str, images: dict[str, str], sha: str
) -> None:
    attempted: list[dict[str, str]] = []
    try:
        for target in targets:
            attempted.append(target)  # SSH may disconnect after the remote mutation.
            service = "inference" if target["role"] == "inference" else "main"
            result = remote(target, "update", release, image=images[service], sha=sha)
            print(
                f"Updated {target['role']} {target['ssh']}: {result['image']}",
                flush=True,
            )
            for main in targets:
                if main["role"] != "inference":
                    remote(main, "routes", release)
    except BaseException:
        for target in reversed(attempted):
            try:
                remote(target, "rollback", release)
                print(f"Rolled back {target['ssh']}", flush=True)
            except BaseException:
                print(
                    f"ROLLBACK UNCONFIRMED: {target['ssh']}; snapshot .deploy-{release}",
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
        "--check",
        action="store_true",
        help="read-only fleet preflight; no build or update",
    )
    parser.add_argument("--build-timeout", type=int, default=3600)
    args = parser.parse_args()
    targets = inventory(args.inventory)
    release = uuid.uuid4().hex
    prepared: list[dict[str, str]] = []
    rollout_started = False
    rollout_completed = False
    try:
        for target in targets:
            result = remote(target, "check", release)
            print(
                f"Ready: {target['role']} {target['ssh']} ({result['image']})",
                flush=True,
            )
        expected_models = [t["model"] for t in targets if t["role"] == "inference"]
        for target in targets:
            if target["role"] != "inference":
                remote(target, "routes", release, models=expected_models)
        if args.check:
            print("Preflight passed. No changes made. Generation not tested.")
            return 0
        sha, url = build(args.ref, args.build_timeout)
        images = {s: amd64_image(s, sha) for s in ("main", "inference")}
        # Snapshot the entire fleet before the first replacement. Persistent locks
        # also block another invocation if this process is killed or disconnected.
        for target in targets:
            prepared.append(target)
            remote(target, "prepare", release)
        for target in targets:
            service = "inference" if target["role"] == "inference" else "main"
            remote(
                target, "stage", release, image=images[service], models=expected_models
            )
        rollout_started = True
        rollout(targets, release, images, sha)
        rollout_completed = True
        print(
            f"Fleet updated: {sha}\n{url}\nCaddy/vLLM preserved. Generation not tested."
        )
        return 0
    finally:
        for target in reversed(prepared):
            if rollout_started and not rollout_completed:
                print(
                    f"Retained recovery lock: {target['ssh']} release={release}",
                    file=sys.stderr,
                )
                continue
            try:
                remote(target, "unlock", release)
            except Exception:
                print(
                    f"Lock cleanup unconfirmed: {target['ssh']} release={release}",
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
