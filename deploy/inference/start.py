"""Start the engines listed in the generated profile, sequentially, then the API."""

from __future__ import annotations

import argparse
import json
import platform
import re
import subprocess
import sys
from pathlib import Path

from compose_document import compose_document
from host_profile import HostProfile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--restart",
        dest="is_restart",
        action="store_true",
        help="Stop the API and all configured engines first",
    )
    args = parser.parse_args()
    directory = Path(__file__).resolve().parent
    profile = HostProfile.load(directory / "profile.json")
    if json.loads((directory / "docker-compose.yml").read_text()) != compose_document(
        profile
    ):
        raise ValueError(
            "Compose differs from its profile; regenerate and review the deployment"
        )
    architecture = {"x86_64": "amd64", "aarch64": "arm64"}.get(platform.machine())
    if architecture != profile.architecture:
        raise ValueError("Host architecture does not match profile")
    compose = [
        "docker",
        "compose",
        "--env-file",
        str(directory / ".env"),
        "-f",
        str(directory / "docker-compose.yml"),
    ]
    config = subprocess.run(
        [*compose, "config", "--format", "json"],
        cwd=directory,
        capture_output=True,
        text=True,
        check=False,
    )
    if config.returncode:
        raise ValueError(
            "Compose validation failed; check machine settings and secret files locally"
        )
    resolved = json.loads(config.stdout)
    if resolved["name"] != profile.data["projectName"]:
        raise ValueError("Compose project name differs from profile")
    backend = resolved["services"]["backend_inference"]
    if not re.fullmatch(
        r"(?:[A-Za-z0-9][A-Za-z0-9./:_-]*@)?sha256:[0-9a-f]{64}", backend["image"]
    ):
        raise ValueError(
            "Backend image must be pinned by digest or a verified local image ID"
        )
    tail = subprocess.run(
        ["tailscale", "ip", "-4"], capture_output=True, text=True, check=True
    ).stdout.strip()
    if not tail or any(port.get("host_ip") != tail for port in backend["ports"]):
        raise ValueError(
            "Inference API must bind to this host's Tailscale IPv4 address"
        )
    services = list(profile.models.values())
    running = subprocess.run(
        [
            "docker",
            "ps",
            "--filter",
            "label=com.docker.compose.project=" + resolved["name"],
            "--format",
            '{{.Label "com.docker.compose.service"}}',
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.splitlines()
    if set(running) - {*services, "backend_inference", "model_download"}:
        raise ValueError(
            "Retired services are still running in this project; stop them before startup"
        )
    if args.is_restart:
        subprocess.run(
            [
                *compose,
                "stop",
                "--timeout",
                "60",
                "backend_inference",
                *reversed(services),
            ],
            cwd=directory,
            check=True,
        )
    for service in services:
        subprocess.run(
            [*compose, "up", "--detach", "--wait", "--wait-timeout", "1800", service],
            cwd=directory,
            check=True,
        )
    subprocess.run(
        [
            *compose,
            "up",
            "--detach",
            "--no-deps",
            "--force-recreate",
            "backend_inference",
        ],
        cwd=directory,
        check=True,
    )
    subprocess.run([*compose, "ps"], cwd=directory, check=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.CalledProcessError):
        print(
            "Host startup failed; inspect the profile and container state locally.",
            file=sys.stderr,
        )
        sys.exit(1)
