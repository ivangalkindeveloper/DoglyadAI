"""In-memory transport used only by isolated backup tests."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath
from typing import Any


class MemoryDisk:
    def __init__(self) -> None:
        self.files: dict[str, bytes] = {}
        self.directories: set[str] = {""}
        self.deleted: list[str] = []
        self.failure: str | None = None

    def metadata(
        self, relative: str, *, is_missing_allowed: bool = False
    ) -> dict[str, Any] | None:
        if relative in self.files:
            payload = self.files[relative]
            return {
                "name": PurePosixPath(relative).name,
                "type": "file",
                "size": len(payload),
                "sha256": hashlib.sha256(payload).hexdigest(),
            }
        if relative in self.directories:
            return {"name": PurePosixPath(relative).name, "type": "dir"}
        if is_missing_allowed:
            return None
        raise ValueError("Missing test file")

    def list(self, relative: str = "") -> list[dict[str, Any]]:
        prefix = relative + "/" if relative else ""
        return [
            self.metadata(name)
            for name in sorted(set(self.files) | self.directories)
            if name.startswith(prefix)
            and name != relative
            and "/" not in name[len(prefix) :]
        ]

    def mkdir(self, relative: str = "") -> None:
        self.directories.add(relative)

    def upload(
        self, local: Path, relative: str, known_metadata: dict[str, Any] | None = None
    ) -> dict[str, Any]:
        if self.failure and self.failure in relative:
            raise RuntimeError("Synthetic upload failure")
        self.files[relative] = local.read_bytes()
        return self.metadata(relative)

    def download(self, relative: str, local: Path, digest: str, size: int) -> None:
        payload = self.files[relative]
        if hashlib.sha256(payload).hexdigest() != digest or len(payload) != size:
            raise ValueError("Synthetic checksum mismatch")
        with local.open("xb") as output:
            output.write(payload)

    def read_json(self, relative: str) -> dict[str, Any]:
        return json.loads(self.files[relative])

    def delete(self, relative: str) -> None:
        self.deleted.append(relative)
        self.files = {
            key: value
            for key, value in self.files.items()
            if key != relative and not key.startswith(relative + "/")
        }
        self.directories = {
            key
            for key in self.directories
            if key != relative and not key.startswith(relative + "/")
        }
