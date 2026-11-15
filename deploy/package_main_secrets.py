"""Separate application credentials from backup-only credentials during delivery."""

from __future__ import annotations

import argparse
import sys
import tarfile
from pathlib import Path
from typing import BinaryIO


def package_main_secrets(source: Path, environment: str, output: BinaryIO) -> None:
    if environment not in {"development", "production"} or source.is_symlink():
        raise ValueError("Invalid secret source or environment")
    backup_names = {
        f"pgbackrest.{environment}.conf",
        f"yandex-disk.{environment}.conf",
        f"backup-monitor.{environment}.env",
    }
    other = "development" if environment == "production" else "production"
    with tarfile.open(fileobj=output, mode="w|gz") as archive:
        for path in sorted(source.rglob("*")):
            if path.is_symlink() or not (path.is_dir() or path.is_file()):
                raise ValueError("Secrets must contain only regular files/directories")
            if path.is_dir():
                continue
            relative = path.relative_to(source)
            if str(relative) in {".env.running", f".env.{other}"}:
                continue
            if len(relative.parts) == 1 and relative.name.startswith(
                ("pgbackrest.", "yandex-disk.", "backup-monitor.")
            ):
                if relative.name not in backup_names:
                    continue
                destination = "backup-source/" + relative.name
            else:
                destination = "secrets/" + relative.as_posix()
            info = archive.gettarinfo(str(path), arcname=destination)
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            info.mode = 0o600
            with path.open("rb") as content:
                archive.addfile(info, content)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("environment", choices=("development", "production"))
    arguments = parser.parse_args()
    try:
        package_main_secrets(arguments.source, arguments.environment, sys.stdout.buffer)
    except Exception:
        print(
            "Secret packaging failed; check regular files and environment selection",
            file=sys.stderr,
        )
        sys.exit(1)
