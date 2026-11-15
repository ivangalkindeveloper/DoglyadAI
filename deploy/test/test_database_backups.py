from __future__ import annotations

import importlib.util
import io
import json
import sys
import tarfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from package_main import package_main

DIRECTORY = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "backup_status", DIRECTORY / "database/backup-status.py"
)
status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(status)


class DatabaseBackupTests(unittest.TestCase):
    def test_current_full_backup_is_required_even_when_incrementals_are_recent(self):
        document = [
            {
                "name": "doglyad_database",
                "status": {"code": 0},
                "backup": [
                    {"type": "full", "timestamp": {"stop": 100000}},
                    {"type": "incr", "timestamp": {"stop": 200000}},
                ],
            }
        ]
        status.check_backup_status(document, now=110000)
        with self.assertRaises(ValueError):
            status.check_backup_status(document, now=200001)

    def test_unhealthy_repository_or_no_full_copy_is_rejected(self):
        for document in (
            [],
            [{"name": "doglyad_database", "status": {"code": 1}}],
            [{"name": "doglyad_database", "status": {"code": 0}, "backup": []}],
        ):
            with self.subTest(document=document), self.assertRaises(ValueError):
                status.check_backup_status(document, now=100000)

    def test_public_package_contains_complete_stack_and_no_credentials(self):
        output = io.BytesIO()
        package_main(DIRECTORY, output)
        output.seek(0)
        with tarfile.open(fileobj=output, mode="r:gz") as archive:
            names = archive.getnames()
            self.assertIn("docker-compose.yml", names)
            self.assertIn("configure_main.py", names)
            self.assertIn("database/systemd/doglyad-database-status.timer", names)
            self.assertTrue(all(not name.startswith("secrets/") for name in names))
            self.assertTrue(
                all(
                    not Path(name).is_absolute() and ".." not in Path(name).parts
                    for name in names
                )
            )
            manifest = json.loads((DIRECTORY / "main-assets.json").read_text())
            self.assertEqual(set(names), set(manifest.values()))


if __name__ == "__main__":
    unittest.main()
