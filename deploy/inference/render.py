"""Generate a deployable host directory without starting containers or reading secrets."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from compose_document import compose_document
from host_profile import HostProfile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--check",
        dest="is_check",
        action="store_true",
        help="Check generated files without writing",
    )
    args = parser.parse_args()
    profile = HostProfile.load(args.profile)
    source = Path(__file__).resolve().parent
    documents = {
        "docker-compose.yml": compose_document(profile),
        "profile.json": dict(profile.data, serverConfig="config/server.json"),
        "config/server.json": profile.server_config,
    }
    files = {
        name: json.dumps(value, indent=2, ensure_ascii=False) + "\n"
        for name, value in documents.items()
    }
    for name in ("start.py", "host_profile.py", "compose_document.py", "start.sh"):
        files[name] = (source / name).read_text()
    files[".env.example"] = (
        "# Machine settings only; credentials belong in secrets/.\n"
        "INFERENCE_BACKEND_IMAGE=\nINFERENCE_BACKEND_BIND=\nINFERENCE_BACKEND_PORT=8100\n"
    )
    if args.is_check:
        for name, content in files.items():
            path = args.output / name
            if not path.is_file() or path.read_text() != content:
                raise ValueError(f"Generated file is missing or differs: {name}")
        print("Generated deployment matches profile.")
        return 0
    # Never overwrite operational .env, secrets, logs or downloaded weights.
    for name in files:
        path = args.output / name
        if path.is_symlink() or any(
            parent.is_symlink()
            for parent in path.parents
            if parent == args.output or args.output in parent.parents
        ):
            raise ValueError("Generated output paths must not be symbolic links")
    for name, content in files.items():
        path = args.output / name
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(path.name + ".tmp")
        with temporary.open("x") as stream:
            stream.write(content)
        temporary.chmod(0o755 if name == "start.sh" else 0o644)
        temporary.replace(path)
    print(
        f"Generated {args.output}. Review files, then configure .env and secrets before startup."
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f"Generation failed: {error}", file=sys.stderr)
        sys.exit(1)
