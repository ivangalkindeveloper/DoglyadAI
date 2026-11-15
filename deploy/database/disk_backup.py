"""Publish encrypted pgBackRest generations and WAL to Yandex Disk."""

from __future__ import annotations

import argparse
import configparser
import fcntl
import json
import os
import re
import sys
import tarfile
import tempfile
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any

from yandex_disk import YandexDisk

PART_SIZE = 512 * 1024 * 1024
GENERATION = re.compile(
    r"doglyad_database-(development|production)-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{6}Z-[0-9a-f]{32}"
)
CHECKPOINT = re.compile(r"checkpoint-\d{20}-[0-9a-f]{32}\.json")


class DiskBackup:
    def __init__(
        self, disk: YandexDisk, environment: str, repository: Path, state: Path
    ) -> None:
        if environment not in {"development", "production"}:
            raise ValueError("Invalid backup environment")
        self.disk = disk
        self.environment = environment
        self.repository = repository
        self.state = state

    def publish(self, information: list[dict[str, Any]]) -> None:
        backup = self._full_backup(information)
        generation = (
            "doglyad_database-"
            + self.environment
            + "-"
            + datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%S.%fZ")
            + "-"
            + uuid.uuid4().hex
        )
        self.disk.mkdir()
        previous = self._generations()
        self.disk.mkdir(generation)
        # pgBackRest has already encrypted each file. No application/backup keys enter the tar.
        with tempfile.TemporaryDirectory(dir=self.state.parent) as directory:
            work = Path(directory)
            archive = work / "snapshot.tar.gz"
            with tarfile.open(
                archive, "w:gz", compresslevel=1, dereference=True
            ) as output:
                for path in sorted(self.repository.rglob("*")):
                    relative = path.relative_to(self.repository)
                    if path.is_symlink():
                        if (
                            relative == Path("backup/doglyad_database/latest")
                            and os.readlink(path) == backup["label"]
                        ):
                            continue
                        raise ValueError("Backup repository must not contain symlinks")
                    if path.is_file() and (
                        relative.parts[0] == "backup"
                        or path.name in {"archive.info", "archive.info.copy"}
                    ):
                        output.add(path, arcname=str(relative), recursive=False)
            parts = []
            with archive.open("rb") as source:
                index = 0
                while True:
                    first = source.read(min(PART_SIZE, 1024 * 1024))
                    if not first:
                        break
                    part = work / f"{generation}.tar.gz.part{index:05d}"
                    with part.open("wb") as output:
                        output.write(first)
                        remaining = PART_SIZE - len(first)
                        while remaining:
                            chunk = source.read(min(remaining, 1024 * 1024))
                            if not chunk:
                                break
                            output.write(chunk)
                            remaining -= len(chunk)
                    metadata = self.disk.upload(part, generation + "/" + part.name)
                    parts.append(self._entry(part.name, metadata))
                    part.unlink()
                    index += 1
            manifest = {
                "version": 1,
                "environment": self.environment,
                "generation": generation,
                "label": backup["label"],
                "stop": backup["timestamp"]["stop"],
                "parts": parts,
            }
            self._upload_json(manifest, generation + "/manifest.json")
        self._sync_wal(manifest)
        self._save_state(manifest)
        # Keep the old remote generation until every part and the WAL checkpoint are verified.
        for old in previous:
            self.disk.delete(old)
        print("Published encrypted database backup: " + generation)

    def synchronize(self, information: list[dict[str, Any]]) -> None:
        manifest = json.loads(self.state.read_text())
        self._validate_manifest(manifest)
        if self._full_backup(information)["label"] != manifest["label"]:
            raise ValueError("Publish the new full backup before synchronizing WAL")
        self._sync_wal(manifest)

    def check(self) -> None:
        manifest, checkpoint = self._latest()
        self._fresh(manifest["stop"], 26 * 3600)
        self._fresh(checkpoint["time"], 10 * 60)
        self._verify_entries(
            manifest["generation"], manifest["parts"] + checkpoint["wal"]
        )

    def fetch(self, destination: Path) -> None:
        manifest, checkpoint = self._latest()
        if destination.exists():
            raise ValueError("Restore destination must not already exist")
        destination.mkdir(mode=0o700, parents=True)
        with tempfile.TemporaryDirectory(dir=destination.parent) as directory:
            archive = Path(directory) / "snapshot.tar.gz"
            with archive.open("xb") as output:
                for index, entry in enumerate(manifest["parts"]):
                    part = Path(directory) / str(index)
                    self.disk.download(
                        manifest["generation"] + "/" + entry["path"],
                        part,
                        entry["sha256"],
                        entry["size"],
                    )
                    with part.open("rb") as source:
                        while chunk := source.read(1024 * 1024):
                            output.write(chunk)
                    part.unlink()
            with tarfile.open(archive, "r:gz") as source:
                for member in source:
                    path = self._relative(member.name)
                    if not member.isfile() or path.parts[0] not in {
                        "backup",
                        "archive",
                    }:
                        raise ValueError("Unsafe backup archive member")
                    target = destination / path
                    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                    contents = source.extractfile(member)
                    if contents is None:
                        raise ValueError("Missing backup archive member")
                    with contents, target.open("xb") as output:
                        while chunk := contents.read(1024 * 1024):
                            output.write(chunk)
                    target.chmod(0o600)
        for entry in checkpoint["wal"]:
            path = self._relative(entry["path"])
            target = destination / path
            target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            self.disk.download(
                manifest["generation"] + "/" + entry["path"],
                target,
                entry["sha256"],
                entry["size"],
            )
            target.chmod(0o600)
        print("Downloaded and verified backup repository: " + manifest["generation"])

    def _sync_wal(self, manifest: dict[str, Any]) -> None:
        self._fresh(manifest["stop"], 26 * 3600)
        generation = manifest["generation"]
        entries = []
        directories: dict[str, dict[str, Any]] = {}
        for path in sorted((self.repository / "archive").rglob("*")):
            if path.is_symlink():
                raise ValueError("WAL repository must not contain symlinks")
            if not path.is_file() or path.name in {"archive.info", "archive.info.copy"}:
                continue
            # archive-push installs complete files atomically; its temporary files are not WAL.
            if not re.fullmatch(
                r"(?:[0-9A-F]{24}-[0-9a-f]{40}(?:\.[a-z0-9]+)?|[0-9A-F]{8}\.history)",
                path.name,
            ):
                continue
            relative = path.relative_to(self.repository).as_posix()
            parent = str(PurePosixPath(generation + "/" + relative).parent)
            if parent not in directories:
                self.disk.mkdir(parent)
                directories[parent] = {
                    item["name"]: item for item in self.disk.list(parent)
                }
            metadata = self.disk.upload(
                path, generation + "/" + relative, directories[parent].get(path.name)
            )
            entries.append(self._entry(relative, metadata))
        if not entries:
            raise ValueError("No archived WAL found")
        checkpoint = {"generation": generation, "time": time.time(), "wal": entries}
        name = f"checkpoint-{time.time_ns():020d}-{uuid.uuid4().hex}.json"
        self._upload_json(checkpoint, generation + "/" + name)
        for item in self.disk.list(generation):
            if CHECKPOINT.fullmatch(item["name"]) and item["name"] != name:
                self.disk.delete(generation + "/" + item["name"])

    def _latest(self) -> tuple[dict[str, Any], dict[str, Any]]:
        for generation in reversed(self._generations()):
            checkpoints = sorted(
                item["name"]
                for item in self.disk.list(generation)
                if CHECKPOINT.fullmatch(item["name"])
            )
            if not checkpoints:
                continue
            manifest = self.disk.read_json(generation + "/manifest.json")
            self._validate_manifest(manifest)
            if manifest["generation"] != generation:
                raise ValueError("Backup generation mismatch")
            checkpoint = self.disk.read_json(generation + "/" + checkpoints[-1])
            if checkpoint["generation"] != generation or not checkpoint["wal"]:
                raise ValueError("Invalid WAL checkpoint")
            for entry in checkpoint["wal"]:
                if self._relative(entry["path"]).parts[0] != "archive":
                    raise ValueError("Invalid WAL path")
                self._validate_entry(entry)
            return manifest, checkpoint
        raise ValueError("No completed remote database backup")

    def _validate_manifest(self, manifest: dict[str, Any]) -> None:
        generation = manifest["generation"]
        match = GENERATION.fullmatch(generation)
        if (
            not match
            or match[1] != self.environment
            or manifest.get("version") != 1
            or manifest["environment"] != self.environment
            or not manifest["parts"]
        ):
            raise ValueError("Invalid database backup manifest")
        for index, part in enumerate(manifest["parts"]):
            if part["path"] != f"{generation}.tar.gz.part{index:05d}":
                raise ValueError("Invalid backup part sequence")
            self._validate_entry(part)

    def _generations(self) -> list[str]:
        return sorted(
            item["name"]
            for item in self.disk.list()
            if item.get("type") == "dir"
            and (match := GENERATION.fullmatch(item["name"]))
            and match[1] == self.environment
        )

    def _verify_entries(self, generation: str, entries: list[dict[str, Any]]) -> None:
        directories: dict[str, dict[str, Any]] = {}
        for entry in entries:
            path = PurePosixPath(generation + "/" + entry["path"])
            parent = str(path.parent)
            if parent not in directories:
                directories[parent] = {
                    item["name"]: item for item in self.disk.list(parent)
                }
            metadata = directories[parent].get(path.name)
            if metadata is None:
                raise ValueError("Remote backup is incomplete")
            YandexDisk._verify(metadata, entry["sha256"], entry["size"])

    def _upload_json(self, document: dict[str, Any], relative: str) -> None:
        with tempfile.TemporaryDirectory(dir=self.state.parent) as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps(document, separators=(",", ":")))
            self.disk.upload(path, relative)

    def _save_state(self, manifest: dict[str, Any]) -> None:
        temporary = self.state.with_suffix(".tmp")
        temporary.write_text(json.dumps(manifest))
        temporary.chmod(0o600)
        os.replace(temporary, self.state)

    @staticmethod
    def _entry(path: str, metadata: dict[str, Any]) -> dict[str, Any]:
        return {"path": path, "sha256": metadata["sha256"], "size": metadata["size"]}

    @staticmethod
    def _validate_entry(entry: dict[str, Any]) -> None:
        if (
            not re.fullmatch(r"[0-9a-f]{64}", entry["sha256"])
            or type(entry["size"]) is not int
            or entry["size"] <= 0
        ):
            raise ValueError("Invalid backup checksum or size")

    @staticmethod
    def _relative(value: str) -> PurePosixPath:
        path = PurePosixPath(value)
        if not value or path.is_absolute() or ".." in path.parts or "\\" in value:
            raise ValueError("Unsafe backup path")
        return path

    @staticmethod
    def _fresh(timestamp: float, maximum_age: int) -> None:
        if not 0 <= time.time() - timestamp + 300 <= maximum_age + 300:
            raise ValueError("Backup or WAL checkpoint is stale or has an invalid time")

    @staticmethod
    def _full_backup(information: list[dict[str, Any]]) -> dict[str, Any]:
        if (
            len(information) != 1
            or information[0]["name"] != "doglyad_database"
            or information[0]["status"]["code"] != 0
        ):
            raise ValueError("Unhealthy pgBackRest repository")
        backup = max(
            (item for item in information[0]["backup"] if item["type"] == "full"),
            key=lambda item: item["timestamp"]["stop"],
        )
        DiskBackup._fresh(backup["timestamp"]["stop"], 26 * 3600)
        return backup


def _main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("publish", "sync", "check", "fetch"))
    parser.add_argument(
        "--config", type=Path, default=Path("database-secrets/yandex-disk.conf")
    )
    parser.add_argument("--destination", type=Path)
    arguments = parser.parse_args()
    config = configparser.ConfigParser(interpolation=None)
    config.read(arguments.config)
    settings = config["disk"]
    environment = settings["environment"]
    if settings["folder"] != "/DoglyadAIDB/" + environment:
        raise ValueError("Disk folder must match the environment")
    state_directory = Path("database-backups")
    state_directory.mkdir(mode=0o700, exist_ok=True)
    with (state_directory / "disk.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        service = DiskBackup(
            YandexDisk(settings["token"], settings["folder"]),
            environment,
            state_directory / "repository",
            state_directory / "current.json",
        )
        match arguments.operation:
            case "publish":
                service.publish(json.load(sys.stdin))
            case "sync":
                service.synchronize(json.load(sys.stdin))
            case "check":
                service.check()
            case "fetch":
                if arguments.destination is None:
                    raise ValueError("Specify a new restore destination")
                service.fetch(arguments.destination)


if __name__ == "__main__":
    try:
        _main()
    except Exception:
        print(
            "Yandex Disk backup operation failed; inspect configuration, connectivity, quota and backup freshness. No success heartbeat was sent.",
            file=sys.stderr,
        )
        sys.exit(1)
