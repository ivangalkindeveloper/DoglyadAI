from __future__ import annotations

import hashlib
import io
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "database"))
from package_main_secrets import package_main_secrets
from yandex_disk import YandexDisk


class YandexDiskTests(unittest.TestCase):
    def test_async_upload_waits_for_hash_verified_resource(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "part"
            path.write_bytes(b"encrypted")
            disk = YandexDisk("synthetic-token", "/DoglyadAIDB/production")
            connection = MagicMock()
            connection.getresponse.return_value.status = 202
            metadata = {
                "type": "file",
                "size": 9,
                "sha256": hashlib.sha256(b"encrypted").hexdigest(),
            }
            with (
                patch.object(disk, "metadata", side_effect=[None, None, metadata]),
                patch.object(disk, "_api", return_value=(200, {})),
                patch.object(disk, "_transfer", return_value=(connection, "/upload")),
                patch("yandex_disk.time.sleep") as sleep,
            ):
                self.assertEqual(disk.upload(path, "part"), metadata)
            sleep.assert_called_once_with(2)

    def test_upload_checksum_mismatch_is_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "part"
            path.write_bytes(b"encrypted")
            disk = YandexDisk("synthetic-token", "/DoglyadAIDB/production")
            connection = MagicMock()
            connection.getresponse.return_value.status = 201
            with (
                patch.object(
                    disk,
                    "metadata",
                    side_effect=[None, {"type": "file", "size": 9, "sha256": "0" * 64}],
                ),
                patch.object(disk, "_api", return_value=(200, {})),
                patch.object(disk, "_transfer", return_value=(connection, "/upload")),
                self.assertRaises(ValueError),
            ):
                disk.upload(path, "part")

    def test_listing_reads_all_pages(self):
        disk = YandexDisk("synthetic-token", "/DoglyadAIDB/production")
        with patch.object(
            disk,
            "_api",
            side_effect=[
                (200, {"_embedded": {"total": 2, "items": [{"name": "first"}]}}),
                (200, {"_embedded": {"total": 2, "items": [{"name": "last"}]}}),
            ],
        ) as api:
            self.assertEqual([item["name"] for item in disk.list()], ["first", "last"])
        self.assertEqual(api.call_args_list[1].args[2]["offset"], 1)

    def test_api_errors_do_not_include_provider_body_or_oauth(self):
        disk = YandexDisk("synthetic-secret-token", "/DoglyadAIDB/production")
        connection = MagicMock()
        connection.getresponse.return_value.status = 403
        connection.getresponse.return_value.read.return_value = (
            b'{"error":"sensitive-provider-detail"}'
        )
        with (
            patch("yandex_disk.http.client.HTTPSConnection", return_value=connection),
            self.assertRaisesRegex(RuntimeError, r"HTTP 403") as error,
        ):
            disk.metadata("private")
        self.assertNotIn("synthetic-secret-token", str(error.exception))
        self.assertNotIn("sensitive-provider-detail", str(error.exception))

    def test_deletion_uses_permanent_mode_and_waits_until_resource_is_absent(self):
        disk = YandexDisk("synthetic-token", "/DoglyadAIDB/production")
        with (
            patch.object(disk, "_api", return_value=(202, {})) as api,
            patch.object(disk, "metadata", side_effect=[{"type": "dir"}, None]),
            patch("yandex_disk.time.sleep"),
        ):
            disk.delete("old-generation")
        self.assertEqual(api.call_args.args[2]["permanently"], "true")

    def test_credentials_are_delivered_outside_application_mount(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            files = {
                ".env": "common",
                ".env.production": "production",
                ".env.development": "development",
                ".env.running": "generated",
                "yandex-disk.production.conf": "synthetic-token",
                "yandex-disk.development.conf": "other-token",
                "pgbackrest.production.conf": "synthetic-key",
                "backup-monitor.production.env": "synthetic-heartbeat",
                "apple/key.p8": "synthetic-apple",
            }
            for name, payload in files.items():
                target = root / name
                target.parent.mkdir(exist_ok=True)
                target.write_text(payload)
            output = io.BytesIO()
            package_main_secrets(root, "production", output)
            output.seek(0)
            with tarfile.open(fileobj=output, mode="r:gz") as archive:
                self.assertEqual(
                    set(archive.getnames()),
                    {
                        "secrets/.env",
                        "secrets/.env.production",
                        "secrets/apple/key.p8",
                        "backup-source/yandex-disk.production.conf",
                        "backup-source/pgbackrest.production.conf",
                        "backup-source/backup-monitor.production.env",
                    },
                )
                self.assertTrue(all(item.mode == 0o600 for item in archive))


if __name__ == "__main__":
    unittest.main()
