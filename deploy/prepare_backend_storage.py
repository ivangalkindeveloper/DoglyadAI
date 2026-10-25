"""Run as root in a temporary backend container before non-root startup."""

from __future__ import annotations

import os
from pathlib import Path


def prepare_backend_storage(root: Path) -> None:
    if os.geteuid() != 0:
        raise PermissionError("Storage preparation requires root")
    for name in ("secrets", "logs"):
        directory = root / name
        if not directory.is_dir() or directory.is_symlink():
            raise ValueError("Expected a mounted storage directory")
        for path in (directory, *directory.rglob("*")):
            if path.is_symlink() or not (path.is_dir() or path.is_file()):
                raise ValueError(
                    "Storage must contain only regular files and directories"
                )
            # Preserve the host owner's access. Only this dedicated container group
            # can additionally read credentials or write logs; no world permissions.
            os.chown(path, -1, 10001)
            if name == "secrets":
                path.chmod(0o750 if path.is_dir() else 0o640)
            else:
                path.chmod(0o2770 if path.is_dir() else 0o660)


if __name__ == "__main__":
    prepare_backend_storage(Path("/storage"))
