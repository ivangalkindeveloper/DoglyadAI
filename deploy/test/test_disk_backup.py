from __future__ import annotations

import io
import json
import sys
import tarfile
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "database"))
from disk_backup import GENERATION, DiskBackup
from memory_disk import MemoryDisk
from yandex_disk import YandexDisk


class DiskBackupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repository = self.root / "repository"
        (self.repository / "backup/doglyad_database/full").mkdir(parents=True)
        (self.repository / "archive/doglyad_database/17-1/0000000100000000").mkdir(
            parents=True
        )
        (self.repository / "backup/doglyad_database/backup.info").write_bytes(
            b"encrypted-info"
        )
        (self.repository / "backup/doglyad_database/full/data").write_bytes(
            b"encrypted-database"
        )
        (self.repository / "archive/doglyad_database/archive.info").write_bytes(
            b"encrypted-archive-info"
        )
        self.wal = self.repository / (
            "archive/doglyad_database/17-1/0000000100000000/"
            + "0" * 24
            + "-"
            + "a" * 40
            + ".zst"
        )
        self.wal.write_bytes(b"encrypted-wal")
        self.disk = MemoryDisk()
        self.service = DiskBackup(
            self.disk, "production", self.repository, self.root / "current.json"
        )
        self.information = [
            {
                "name": "doglyad_database",
                "status": {"code": 0},
                "backup": [
                    {
                        "type": "full",
                        "label": "synthetic-full",
                        "timestamp": {"stop": time.time()},
                    }
                ],
            }
        ]

    def test_publish_sync_and_fetch_restore_identical_repository(self):
        self.service.publish(self.information)
        self.wal.with_name("1" * 24 + "-" + "b" * 40 + ".zst").write_bytes(
            b"new-encrypted-wal"
        )
        self.service.synchronize(self.information)
        self.service.check()
        destination = self.root / "restored"
        self.service.fetch(destination)
        self.assertEqual(
            {
                p.relative_to(self.repository): p.read_bytes()
                for p in self.repository.rglob("*")
                if p.is_file()
            },
            {
                p.relative_to(destination): p.read_bytes()
                for p in destination.rglob("*")
                if p.is_file()
            },
        )
        self.assertTrue(
            GENERATION.fullmatch(
                json.loads((self.root / "current.json").read_text())["generation"]
            )
        )

    def test_failed_replacement_preserves_previous_remote_copy(self):
        self.service.publish(self.information)
        old = json.loads((self.root / "current.json").read_text())["generation"]
        for failure in (".part", "/archive/", "checkpoint-"):
            self.disk.failure = failure
            with self.assertRaises(RuntimeError):
                self.service.publish(self.information)
            self.assertIn(old + "/manifest.json", self.disk.files)
            self.assertNotIn(old, self.disk.deleted)
            self.assertEqual(
                json.loads((self.root / "current.json").read_text())["generation"], old
            )
        self.disk.failure = None
        self.service.publish(self.information)
        self.assertIn(old, self.disk.deleted)
        self.assertEqual(len(self.service._generations()), 1)

    def test_cleanup_preserves_user_files_and_other_environment(self):
        self.disk.files["notes.txt"] = b"user-owned"
        other = "doglyad_database-development-2026-11-15T12-30-00.000000Z-" + "a" * 32
        self.disk.mkdir(other)
        self.service.publish(self.information)
        self.service.publish(self.information)
        self.assertIn("notes.txt", self.disk.files)
        self.assertIn(other, self.disk.directories)
        self.assertNotIn(other, self.disk.deleted)

    def test_missing_or_corrupted_remote_part_prevents_health_success(self):
        self.service.publish(self.information)
        name = next(name for name in self.disk.files if ".part" in name)
        self.disk.files[name] = b"corrupted"
        with self.assertRaises(ValueError):
            self.service.check()

    def test_stale_checkpoint_and_new_unpublished_full_backup_fail(self):
        self.service.publish(self.information)
        name = next(name for name in self.disk.files if "checkpoint-" in name)
        checkpoint = json.loads(self.disk.files[name])
        checkpoint["time"] -= 601
        self.disk.files[name] = json.dumps(checkpoint).encode()
        with self.assertRaises(ValueError):
            self.service.check()
        self.information[0]["backup"][0]["label"] = "new-unpublished-full"
        with self.assertRaises(ValueError):
            self.service.synchronize(self.information)

    def test_parts_are_bounded_and_reassembled(self):
        with patch("disk_backup.PART_SIZE", 64):
            self.service.publish(self.information)
        parts = [value for key, value in self.disk.files.items() if ".part" in key]
        self.assertGreater(len(parts), 1)
        self.assertTrue(all(len(part) <= 64 for part in parts))
        self.service.fetch(self.root / "restored")

    def test_manifest_cannot_escape_restore_directory(self):
        self.service.publish(self.information)
        name = next(name for name in self.disk.files if name.endswith("manifest.json"))
        manifest = json.loads(self.disk.files[name])
        manifest["parts"][0]["path"] = "../outside"
        self.disk.files[name] = json.dumps(manifest).encode()
        with self.assertRaises(ValueError):
            self.service.fetch(self.root / "restored")

    def test_tar_links_are_rejected(self):
        self.service.publish(self.information)
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode="w:gz") as output:
            member = tarfile.TarInfo("backup/link")
            member.type = tarfile.SYMTYPE
            member.linkname = "/etc/passwd"
            output.addfile(member)
        part_name = next(name for name in self.disk.files if ".part" in name)
        self.disk.files[part_name] = archive.getvalue()
        manifest_name = next(
            name for name in self.disk.files if name.endswith("manifest.json")
        )
        manifest = json.loads(self.disk.files[manifest_name])
        manifest["parts"][0].update(
            self.service._entry(
                manifest["parts"][0]["path"], self.disk.metadata(part_name)
            )
        )
        self.disk.files[manifest_name] = json.dumps(manifest).encode()
        with self.assertRaises(ValueError):
            self.service.fetch(self.root / "restored")

    def test_transport_never_sends_oauth_to_transfer_host(self):
        disk = YandexDisk("synthetic-token", "/DoglyadAIDB/production")
        connection = MagicMock()
        response = connection.getresponse.return_value
        response.status = 201
        path = self.root / "upload"
        path.write_bytes(b"synthetic")
        metadata = {"type": "file", "size": 9, "sha256": disk._digest(path)}
        with (
            patch.object(disk, "metadata", side_effect=[None, metadata]),
            patch.object(
                disk,
                "_api",
                return_value=(
                    200,
                    {"href": "https://uploader.dst.yandex.net/file", "method": "PUT"},
                ),
            ),
            patch.object(disk, "_transfer", return_value=(connection, "/file")),
        ):
            disk.upload(path, "backup")
        headers = connection.request.call_args.kwargs["headers"]
        self.assertNotIn("Authorization", headers)
        self.assertNotIn("synthetic-token", str(connection.mock_calls))

    def test_transfer_rejects_insecure_or_unrelated_hosts(self):
        for url in (
            "http://uploader.yandex.net/file",
            "https://evil.example/file",
            "https://yandex.net.evil.example/file",
            "https://user:pass@uploader.yandex.net/file",
        ):
            with self.subTest(url=url), self.assertRaises(ValueError):
                YandexDisk._transfer({"href": url, "method": "PUT"}, "PUT")


if __name__ == "__main__":
    unittest.main()
