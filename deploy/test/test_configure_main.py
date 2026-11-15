from __future__ import annotations

import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

DIRECTORY = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "configure_main", DIRECTORY / "configure_main.py"
)
configure = importlib.util.module_from_spec(spec)
spec.loader.exec_module(configure)


class ConfigureMainTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "secrets").mkdir()
        (self.root / "backup-source").mkdir()
        (self.root / "prepare_backend_storage.py").write_text("fixture")
        (self.root / ".main-assets-sha").write_text("a" * 40 + "\n")
        (self.root / ".env").write_text(
            "TAG="
            + "a" * 40
            + "\nENV_FILE=secrets/.env.production\nDOMAIN=example.com\nDATABASE_IMAGE=ghcr.io/ivangalkindeveloper/doglyad-database@sha256:"
            + "b" * 64
            + "\n"
        )
        (self.root / "secrets/.env.production").write_text(
            "ENVIRONMENT=production\nDATABASE_PASSWORD=synthetic\nDATABASE_URL=postgresql+asyncpg://doglyad:synthetic@doglyad_database:5432/doglyad_database\n"
        )
        source = (DIRECTORY / "database/pgbackrest.conf.example").read_text()
        source = source.replace(
            "REPLACE_WITH_SEPARATELY_STORED_RANDOM_KEY", "synthetic-encryption-key"
        )
        (self.root / "backup-source/yandex-disk.production.conf").write_text(
            "[disk]\nenvironment=production\nfolder=/DoglyadAIDB/production\ntoken=synthetic-token\n"
        )
        (self.root / "backup-source/pgbackrest.production.conf").write_text(source)
        (self.root / "backup-source/backup-monitor.production.env").write_text(
            "DATABASE_BACKUP_SUCCESS_URL=https://monitor.example/daily\nDATABASE_BACKUP_STATUS_URL=https://monitor.example/status\n"
        )

    def test_valid_config_check_never_runs_services(self):
        with patch.object(configure, "_run") as run, patch("builtins.print"):
            configure.configure_main(self.root, is_check_only=True)
        run.assert_not_called()
        self.assertFalse((self.root / "database-secrets").exists())

    def test_wrong_disk_environment_or_missing_token_blocks_setup(self):
        path = self.root / "backup-source/yandex-disk.production.conf"
        original = path.read_text()
        for invalid in (
            original.replace("/DoglyadAIDB/production", "/DoglyadAIDB/development"),
            original.replace("synthetic-token", "REPLACE_WITH_TOKEN"),
        ):
            path.write_text(invalid)
            with patch.object(configure, "_run") as run, self.assertRaises(ValueError):
                configure.configure_main(self.root)
            run.assert_not_called()

    def test_database_password_mismatch_blocks_setup_before_commands(self):
        path = self.root / "secrets/.env.production"
        path.write_text(
            path.read_text().replace(
                "DATABASE_PASSWORD=synthetic", "DATABASE_PASSWORD=other"
            )
        )
        with patch.object(configure, "_run") as run, self.assertRaises(ValueError):
            configure.configure_main(self.root)
        run.assert_not_called()

    def test_cloud_repository_is_rejected(self):
        path = self.root / "backup-source/pgbackrest.production.conf"
        path.write_text(path.read_text().replace("repo1-type=posix", "repo1-type=s3"))
        with patch.object(configure, "_run") as run, self.assertRaises(ValueError):
            configure.configure_main(self.root)
        run.assert_not_called()

    def test_zero_retention_is_rejected_before_startup(self):
        path = self.root / "backup-source/pgbackrest.production.conf"
        path.write_text(
            path.read_text().replace("repo1-retention-full=1", "repo1-retention-full=0")
        )
        with patch.object(configure, "_run") as run, self.assertRaises(ValueError):
            configure.configure_main(self.root)
        run.assert_not_called()

    def test_setup_stops_writers_and_backs_up_before_migration(self):
        machine = self.root / ".env"
        machine.write_text(
            "\n".join(
                line
                for line in machine.read_text().splitlines()
                if not line.startswith("DATABASE_IMAGE=")
            )
            + "\n"
        )
        units = self.root / "units"
        units.mkdir()
        source_units = self.root / "database/systemd"
        source_units.mkdir(parents=True)
        for timer in configure.TIMERS:
            for suffix in (".service", ".timer"):
                (source_units / Path(timer).with_suffix(suffix)).write_text("fixture")
        cwd = Path.cwd()
        self.addCleanup(os.chdir, cwd)

        def execute(*args, **kwargs):
            if "{{index .RepoDigests 0}}" in args:
                return "ghcr.io/ivangalkindeveloper/doglyad-database@sha256:" + "b" * 64
            return "999" if "id" in args else ""

        with (
            patch.object(configure, "SYSTEMD_DIRECTORY", units),
            patch.object(configure.os, "geteuid", return_value=0),
            patch.object(configure.os, "chown"),
            patch("builtins.print"),
            patch.object(
                configure,
                "_run",
                side_effect=execute,
            ) as run,
        ):
            configure.configure_main(self.root)
        calls = [call.args for call in run.call_args_list]
        stop = next(i for i, call in enumerate(calls) if "stop" in call)
        backup = next(
            i
            for i, call in enumerate(calls)
            if "start" in call and "doglyad-database-backup.service" in call
        )
        migration = next(
            i for i, call in enumerate(calls) if "database_migrate" in call
        )
        self.assertLess(stop, backup)
        self.assertLess(backup, migration)
        self.assertIn(
            "DATABASE_IMAGE=ghcr.io/ivangalkindeveloper/doglyad-database@sha256:"
            + "b" * 64,
            machine.read_text(),
        )
        self.assertEqual(
            (self.root / "database-secrets/pgbackrest.conf").stat().st_mode & 0o777,
            0o640,
        )
        self.assertEqual(
            (self.root / "database-secrets/backup-monitor.env").stat().st_mode & 0o777,
            0o600,
        )
        self.assertEqual(
            {path.name for path in units.iterdir()},
            {
                "doglyad-database-backup.service",
                "doglyad-database-backup.timer",
                "doglyad-database-status.service",
                "doglyad-database-status.timer",
            },
        )


if __name__ == "__main__":
    unittest.main()
