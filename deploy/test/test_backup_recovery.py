"""Opt-in PostgreSQL/pgBackRest recovery test with synthetic, isolated data."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "database"))
from disk_backup import DiskBackup
from memory_disk import MemoryDisk


@unittest.skipUnless(
    os.environ.get("DOGLYAD_TEST_BACKUP_IMAGE"),
    "Set DOGLYAD_TEST_BACKUP_IMAGE for the Docker recovery test",
)
class BackupRecoveryTests(unittest.TestCase):
    def test_full_backup_and_wal_restore_to_selected_time(self):
        image = os.environ["DOGLYAD_TEST_BACKUP_IMAGE"]
        prefix = "doglyad-backup-test-" + uuid.uuid4().hex[:12]
        source, recovered = prefix + "-source", prefix + "-recovered"
        data, repository, config, restored = (
            prefix + suffix
            for suffix in ("-data", "-repository", "-config", "-restored")
        )

        def execute(*args, input_text=None, timeout=180):
            result = subprocess.run(
                args, input=input_text, capture_output=True, text=True, timeout=timeout
            )
            if result.returncode:
                self.fail(
                    "Isolated backup test command failed: "
                    + args[0]
                    + "\n"
                    + (result.stdout + result.stderr)[-4000:]
                )
            return result.stdout.strip()

        def cleanup():
            for name in (source, recovered):
                subprocess.run(["docker", "rm", "-f", name], capture_output=True)
            for name in (data, repository, config, restored):
                subprocess.run(["docker", "volume", "rm", name], capture_output=True)

        self.addCleanup(cleanup)
        for name in (data, repository, config, restored):
            execute("docker", "volume", "create", name)
        configuration = """[global]
repo1-type=posix
repo1-path=/repository
repo1-cipher-type=aes-256-cbc
repo1-cipher-pass=synthetic-backup-test-key-not-a-real-secret
repo1-retention-full-type=count
repo1-retention-full=1
repo1-retention-history=0
compress-type=zst
[doglyad_database]
pg1-path=/var/lib/postgresql/data
pg1-user=doglyad
pg1-database=doglyad_database
"""
        execute(
            "docker",
            "run",
            "--rm",
            "-i",
            "--network",
            "none",
            "--entrypoint",
            "sh",
            "-v",
            repository + ":/repository",
            "-v",
            config + ":/configuration",
            image,
            "-c",
            "chown postgres:postgres /repository; cat > /configuration/pgbackrest.conf; chown root:postgres /configuration/pgbackrest.conf; chmod 640 /configuration/pgbackrest.conf",
            input_text=configuration,
        )
        mounts = (
            "-v",
            config + ":/etc/pgbackrest:ro",
            "-v",
            repository + ":/repository",
        )
        execute(
            "docker",
            "run",
            "-d",
            "--name",
            source,
            "--network",
            "none",
            "-e",
            "POSTGRES_DB=doglyad_database",
            "-e",
            "POSTGRES_USER=doglyad",
            "-e",
            "POSTGRES_PASSWORD=synthetic-test-only",
            "-v",
            data + ":/var/lib/postgresql/data",
            *mounts,
            image,
            "postgres",
            "-c",
            "archive_mode=on",
            "-c",
            "archive_command=pgbackrest --stanza=doglyad_database archive-push %p",
            "-c",
            "archive_timeout=60s",
        )

        def sql(container, statement):
            return execute(
                "docker",
                "exec",
                "-i",
                container,
                "psql",
                "-v",
                "ON_ERROR_STOP=1",
                "-U",
                "doglyad",
                "-d",
                "doglyad_database",
                "-At",
                input_text=statement,
            )

        def ready(container):
            deadline = time.monotonic() + 90
            while time.monotonic() < deadline:
                result = subprocess.run(
                    [
                        "docker",
                        "exec",
                        container,
                        "pg_isready",
                        "-U",
                        "doglyad",
                        "-d",
                        "doglyad_database",
                    ],
                    capture_output=True,
                )
                if result.returncode == 0:
                    return
                time.sleep(1)
            self.fail("Isolated PostgreSQL did not become ready")

        ready(source)
        root = Path(__file__).resolve().parents[2]
        migration = subprocess.run(
            [
                sys.executable,
                "-m",
                "alembic",
                "-c",
                str(root / "backend/main/alembic.ini"),
                "upgrade",
                "head",
                "--sql",
            ],
            cwd=root,
            env={
                **os.environ,
                "ENVIRONMENT": "development",
                "DATABASE_URL": "postgresql+asyncpg://fixture/doglyad_database",
            },
            capture_output=True,
            text=True,
            check=True,
        )
        sql(source, migration.stdout)
        sql(
            source,
            "CREATE TABLE backup_probe (value text); INSERT INTO backup_probe VALUES ('before_backup');",
        )

        def backrest(*args):
            return execute(
                "docker",
                "exec",
                "--user",
                "postgres",
                source,
                "pgbackrest",
                "--stanza=doglyad_database",
                *args,
                timeout=300,
            )

        backrest("stanza-create")
        backrest("check")
        backrest("--type=full", "backup")
        inventory = backrest("--output=json", "info")
        subprocess.run(
            [sys.executable, str(root / "deploy/database/backup-status.py")],
            input=inventory,
            text=True,
            capture_output=True,
            check=True,
        )
        # Backup selection uses metadata recorded in whole seconds.
        completed = max(
            item["timestamp"]["stop"] for item in json.loads(inventory)[0]["backup"]
        )
        current = float(sql(source, "SELECT extract(epoch FROM clock_timestamp());"))
        if current <= completed + 1:
            time.sleep(completed + 1.1 - current)
        sql(source, "INSERT INTO backup_probe VALUES ('after_backup');")
        target = sql(
            source, "SELECT to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS.USOF');"
        )
        sql(source, "INSERT INTO backup_probe VALUES ('after_target');")
        backrest("check")
        execute("docker", "stop", source)
        execute(
            "docker",
            "run",
            "--rm",
            "--network",
            "none",
            "--entrypoint",
            "sh",
            "-v",
            restored + ":/var/lib/postgresql/data",
            image,
            "-c",
            "chown postgres:postgres /var/lib/postgresql/data; chmod 700 /var/lib/postgresql/data",
        )
        restore_mounts = (
            "-v",
            config + ":/etc/pgbackrest:ro",
            "-v",
            repository + ":/repository:ro",
            "-v",
            restored + ":/var/lib/postgresql/data",
        )
        execute(
            "docker",
            "run",
            "--rm",
            "--network",
            "none",
            "--user",
            "postgres",
            "--entrypoint",
            "pgbackrest",
            *restore_mounts,
            image,
            "--stanza=doglyad_database",
            "--type=time",
            "--target=" + target,
            "--target-action=promote",
            "restore",
            timeout=300,
        )
        execute(
            "docker",
            "run",
            "-d",
            "--name",
            recovered,
            "--network",
            "none",
            *restore_mounts,
            image,
            "postgres",
            "-c",
            "archive_mode=off",
        )
        ready(recovered)
        deadline = time.monotonic() + 90
        while sql(recovered, "SELECT pg_is_in_recovery();") != "f":
            if time.monotonic() > deadline:
                self.fail("Point-in-time recovery did not complete")
            time.sleep(1)
        self.assertEqual(
            sql(recovered, "SELECT value FROM backup_probe ORDER BY value;"),
            "after_backup\nbefore_backup",
        )
        self.assertEqual(
            sql(recovered, "SELECT version_num FROM alembic_version;"), "0001_initial"
        )
        # A completed replacement expires the old full copy; recover its newer WAL.
        execute("docker", "start", source)
        ready(source)
        previous_label = json.loads(inventory)[0]["backup"][0]["label"]
        backrest("--type=full", "backup")
        current_backups = json.loads(backrest("--output=json", "info"))[0]["backup"]
        self.assertEqual(len(current_backups), 1)
        self.assertNotEqual(current_backups[0]["label"], previous_label)
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        disk_root = Path(temporary.name)
        disk_repository = disk_root / "repository"
        disk_repository.mkdir()
        execute("docker", "cp", source + ":/repository/.", str(disk_repository))
        disk = MemoryDisk()
        service = DiskBackup(
            disk, "production", disk_repository, disk_root / "current.json"
        )
        service.publish(json.loads(backrest("--output=json", "info")))
        sql(source, "INSERT INTO backup_probe VALUES ('latest_wal');")
        backrest("check")
        execute("docker", "cp", source + ":/repository/.", str(disk_repository))
        service.synchronize(json.loads(backrest("--output=json", "info")))
        service.check()
        downloaded = disk_root / "downloaded"
        service.fetch(downloaded)
        execute(
            "docker",
            "run",
            "--rm",
            "--network",
            "none",
            "--entrypoint",
            "sh",
            "-v",
            str(downloaded) + ":/repository",
            image,
            "-c",
            "chown -R postgres:postgres /repository",
        )
        restore_mounts = tuple(
            str(downloaded) + ":/repository:ro"
            if value == repository + ":/repository:ro"
            else value
            for value in restore_mounts
        )
        execute("docker", "stop", source)
        execute("docker", "rm", "-f", recovered)
        execute("docker", "volume", "rm", restored)
        execute("docker", "volume", "create", restored)
        execute(
            "docker",
            "run",
            "--rm",
            "--network",
            "none",
            "--entrypoint",
            "sh",
            "-v",
            restored + ":/var/lib/postgresql/data",
            image,
            "-c",
            "chown postgres:postgres /var/lib/postgresql/data; chmod 700 /var/lib/postgresql/data",
        )
        execute(
            "docker",
            "run",
            "--rm",
            "--network",
            "none",
            "--user",
            "postgres",
            "--entrypoint",
            "pgbackrest",
            *restore_mounts,
            image,
            "--stanza=doglyad_database",
            "--type=default",
            "restore",
            timeout=300,
        )
        execute(
            "docker",
            "run",
            "-d",
            "--name",
            recovered,
            "--network",
            "none",
            *restore_mounts,
            image,
            "postgres",
            "-c",
            "archive_mode=off",
        )
        ready(recovered)
        deadline = time.monotonic() + 90
        while sql(recovered, "SELECT pg_is_in_recovery();") != "f":
            if time.monotonic() > deadline:
                self.fail("Recovery to the end of the archive did not complete")
            time.sleep(1)
        self.assertEqual(
            sql(recovered, "SELECT value FROM backup_probe ORDER BY value;"),
            "after_backup\nafter_target\nbefore_backup\nlatest_wal",
        )


if __name__ == "__main__":
    unittest.main()
