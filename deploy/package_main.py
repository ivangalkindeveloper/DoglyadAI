"""Package only the public main deployment assets listed in the manifest."""

from __future__ import annotations

import io
import json
import re
import subprocess
import sys
import tarfile
from pathlib import Path
from typing import BinaryIO


def package_main(
    directory: Path, output: BinaryIO, revision: str | None = None
) -> None:
    manifest = json.loads((directory / "main-assets.json").read_text())
    for source, destination in manifest.items():
        for name in (source, destination):
            if Path(name).is_absolute() or ".." in Path(name).parts:
                raise ValueError("Public asset paths must stay within the stack")
        if (
            not (directory / source).is_file()
            or (directory / source).is_symlink()
            or not (directory / source).resolve().is_relative_to(directory.resolve())
        ):
            raise ValueError("Public deployment assets must be regular files")
    with tarfile.open(fileobj=output, mode="w|gz") as archive:
        for source, destination in manifest.items():
            archive.add(directory / source, arcname=destination, recursive=False)
        if revision is not None:
            if not re.fullmatch(r"[0-9a-f]{40}", revision):
                raise ValueError("Invalid deployment source revision")
            content = (revision + "\n").encode()
            info = tarfile.TarInfo(".main-assets-sha")
            info.size = len(content)
            info.mode = 0o644
            archive.addfile(info, io.BytesIO(content))


if __name__ == "__main__":
    directory = Path(__file__).resolve().parent
    dirty = subprocess.run(
        [
            "git",
            "-C",
            str(directory.parent),
            "status",
            "--porcelain",
            "--untracked-files=all",
            "--",
            "deploy",
            ".github/workflows/build.yml",
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    if dirty:
        raise SystemExit(
            "Commit and publish deployment changes before delivering main assets"
        )
    revision = subprocess.run(
        ["git", "-C", str(directory), "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    package_main(directory, sys.stdout.buffer, revision)
