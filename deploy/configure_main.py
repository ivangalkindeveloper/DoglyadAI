"""Validate and initialize the main database, backups and application processes."""

from __future__ import annotations

import argparse
import configparser
import fcntl
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path("/opt/doglyad")
SYSTEMD_DIRECTORY = Path("/etc/systemd/system")
SERVICES = ("backend_main", "report_worker", "billing_gateway", "billing_worker")
TIMERS = ("doglyad-database-backup.timer", "doglyad-database-status.timer")


def _values(path: Path) -> dict[str, str]:
    result = {}
    for line in path.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        key, separator, value = line.partition("=")
        key = key.strip()
        if not separator or key in result:
            raise ValueError("Invalid or duplicated configuration field")
        tokens = shlex.split(value, comments=False)
        if len(tokens) != 1:
            raise ValueError(
                "Configuration values must be nonempty and quoted when needed"
            )
        result[key] = tokens[0]
    return result


def _validate(root: Path) -> tuple[str, Path, Path, Path]:
    machine = _values(root / ".env")
    selected = machine.get("ENV_FILE", "")
    if selected not in {"secrets/.env.development", "secrets/.env.production"}:
        raise ValueError("Select the main environment in ENV_FILE")
    environment = selected.rsplit(".", 1)[1]
    if not re.fullmatch(
        r"[0-9a-f]{40}(?:@sha256:[0-9a-f]{64})?", machine.get("TAG", "")
    ):
        raise ValueError("TAG must pin a successfully published commit SHA")
    if (root / ".main-assets-sha").read_text().strip() != machine["TAG"].split("@", 1)[
        0
    ]:
        raise ValueError(
            "Deliver deployment files from the same commit as the published main image"
        )
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]*", machine.get("DOMAIN", "")):
        raise ValueError("DOMAIN must contain the public main hostname")
    profile = _values(root / selected)
    if profile.get("ENVIRONMENT") != environment:
        raise ValueError("Secret profile does not match the machine environment")
    database = urlsplit(profile.get("DATABASE_URL", ""))
    if (
        database.scheme != "postgresql+asyncpg"
        or database.hostname != "doglyad_database"
        or database.path != "/doglyad_database"
        or database.username != "doglyad"
        or not profile.get("DATABASE_PASSWORD")
        or unquote(database.password or "") != profile["DATABASE_PASSWORD"]
    ):
        raise ValueError(
            "DATABASE_URL and DATABASE_PASSWORD must identify this stack database"
        )
    configuration = root / f"backup-source/pgbackrest.{environment}.conf"
    monitoring = root / f"backup-source/backup-monitor.{environment}.env"
    disk = root / f"backup-source/yandex-disk.{environment}.conf"
    for path in (configuration, monitoring, disk):
        if not path.is_file() or path.is_symlink():
            raise ValueError(
                "Environment-specific backup and monitoring files are required"
            )
    parser = configparser.ConfigParser(interpolation=None)
    parser.read(configuration)
    global_settings = parser["global"]
    value = global_settings.get("repo1-cipher-pass", "")
    if not value or "REPLACE_" in value:
        raise ValueError("Configure a separately stored backup encryption key")
    disk_parser = configparser.ConfigParser(interpolation=None)
    disk_parser.read(disk)
    if (
        disk_parser["disk"].get("environment") != environment
        or disk_parser["disk"].get("folder") != "/DoglyadAIDB/" + environment
        or not disk_parser["disk"].get("token")
        or "REPLACE_" in disk_parser["disk"]["token"]
    ):
        raise ValueError("Configure the Yandex Disk token and environment folder")
    if (
        global_settings.get("repo1-type") != "posix"
        or global_settings.get("repo1-cipher-type") != "aes-256-cbc"
        or global_settings.get("repo1-retention-full-type") != "count"
        or global_settings.get("repo1-retention-full") != "1"
        or global_settings.get("repo1-path") != "/var/lib/pgbackrest/repository"
        or parser["doglyad_database"].get("pg1-database") != "doglyad_database"
        or parser["doglyad_database"].get("pg1-user") != "doglyad"
        or parser["doglyad_database"].get("pg1-path") != "/var/lib/postgresql/data"
    ):
        raise ValueError("Backup policy or repository environment is invalid")
    endpoints = _values(monitoring)
    for key in ("DATABASE_BACKUP_SUCCESS_URL", "DATABASE_BACKUP_STATUS_URL"):
        value = endpoints.get(key, "")
        if (
            urlsplit(value).scheme != "https"
            or not urlsplit(value).hostname
            or "REPLACE_" in value
        ):
            raise ValueError(
                "Configure independent daily and five-minute backup heartbeats"
            )
    return environment, configuration, monitoring, disk


def _run(*args: str, timeout: int = 120, input_text: str | None = None) -> str:
    result = subprocess.run(
        args, input=input_text, text=True, capture_output=True, timeout=timeout
    )
    if result.returncode:
        raise RuntimeError(
            f"{args[0]} failed (exit {result.returncode}); inspect the service on this VM"
        )
    return result.stdout.strip()


def configure_main(root: Path, *, is_check_only: bool = False) -> None:
    environment, configuration, monitoring, disk = _validate(root)
    if is_check_only:
        print(f"Main {environment}: backup configuration is complete")
        return
    if os.geteuid() != 0:
        raise PermissionError(
            "Main setup requires root to install private files and systemd timers"
        )
    os.chdir(root)
    machine = _values(root / ".env")
    image = machine.get("DATABASE_IMAGE")
    if not image:
        tag = (
            "ghcr.io/ivangalkindeveloper/doglyad-database:"
            + machine["TAG"].split("@", 1)[0]
        )
        _run("docker", "pull", tag, timeout=600)
        image = _run(
            "docker", "image", "inspect", tag, "--format", "{{index .RepoDigests 0}}"
        )
        if not re.fullmatch(
            r"ghcr.io/ivangalkindeveloper/doglyad-database@sha256:[0-9a-f]{64}", image
        ):
            raise ValueError(
                "Database image must resolve to a published immutable digest"
            )
        machine_file = root / ".env"
        temporary = root / ".env.database-setup"
        if temporary.is_symlink():
            raise ValueError("Temporary machine configuration must not be a symlink")
        original_owner = machine_file.stat()
        temporary.write_text(
            machine_file.read_text().rstrip() + "\nDATABASE_IMAGE=" + image + "\n"
        )
        temporary.chmod(0o600)
        os.chown(temporary, original_owner.st_uid, original_owner.st_gid)
        os.replace(temporary, machine_file)
    if not re.fullmatch(
        r"ghcr.io/ivangalkindeveloper/doglyad-database@sha256:[0-9a-f]{64}", image
    ):
        raise ValueError("DATABASE_IMAGE must pin the published database image digest")
    _run("docker", "pull", image, timeout=600)
    _run("bash", "main-compose.sh", "config", "--quiet")
    database_id = _run("bash", "main-compose.sh", "ps", "-q", "doglyad_database")
    if database_id:
        current_image = _run("docker", "inspect", database_id, "--format", "{{.Image}}")
        expected_image = _run(
            "docker", "image", "inspect", image, "--format", "{{.Id}}"
        )
        if current_image != expected_image:
            raise RuntimeError(
                "Changing the PostgreSQL image requires a separate database upgrade plan"
            )
    (root / "logs").mkdir(exist_ok=True)
    _run(
        "bash",
        "main-compose.sh",
        "run",
        "--rm",
        "--no-deps",
        "--user",
        "0:0",
        "--volume",
        f"{root}/secrets:/storage/secrets:rw",
        "--volume",
        f"{root}/logs:/storage/logs:rw",
        "--entrypoint",
        "python",
        "backend_main",
        "-",
        input_text=(root / "prepare_backend_storage.py").read_text(),
        timeout=600,
    )
    owner = int(
        _run(
            "docker",
            "run",
            "--rm",
            "--network",
            "none",
            "--entrypoint",
            "id",
            image,
            "-u",
            "postgres",
        )
    )
    group = int(
        _run(
            "docker",
            "run",
            "--rm",
            "--network",
            "none",
            "--entrypoint",
            "id",
            image,
            "-g",
            "postgres",
        )
    )
    backups = root / "database-backups"
    if backups.is_symlink() or (backups / "repository").is_symlink():
        raise ValueError("Backup storage must not be a symlink")
    backups.mkdir(mode=0o700, exist_ok=True)
    backups.chmod(0o700)
    repository = backups / "repository"
    repository.mkdir(mode=0o700, exist_ok=True)
    os.chown(repository, owner, group)
    repository.chmod(0o700)
    private = root / "database-secrets"
    if private.is_symlink():
        raise ValueError("Database secrets directory must not be a symlink")
    private.mkdir(mode=0o700, exist_ok=True)
    private.chmod(0o700)
    os.chown(private, 0, 0)
    for source, name, destination_group, mode in (
        (configuration, "pgbackrest.conf", group, 0o640),
        (monitoring, "backup-monitor.env", 0, 0o600),
        (disk, "yandex-disk.conf", 0, 0o600),
    ):
        destination = private / name
        if destination.is_symlink():
            raise ValueError("Private configuration must not be a symlink")
        if (
            destination.exists()
            and name == "pgbackrest.conf"
            and source.read_bytes() != destination.read_bytes()
        ):
            raise RuntimeError(
                "Changing the backup repository or its keys requires a separate verified rotation"
            )
        if not destination.exists() or source.read_bytes() != destination.read_bytes():
            shutil.copyfile(source, destination)
        os.chown(destination, 0, destination_group)
        destination.chmod(mode)
    for timer in TIMERS:
        for suffix in (".service", ".timer"):
            name = str(Path(timer).with_suffix(suffix))
            shutil.copyfile(root / "database/systemd" / name, SYSTEMD_DIRECTORY / name)
    _run("systemctl", "daemon-reload")
    if not database_id:
        _run(
            "bash",
            "main-compose.sh",
            "up",
            "-d",
            "--wait",
            "--wait-timeout",
            "120",
            "doglyad_database",
            timeout=180,
        )
    _run(
        "bash",
        "main-compose.sh",
        "exec",
        "-T",
        "--user",
        "postgres",
        "doglyad_database",
        "pgbackrest",
        "--stanza=doglyad_database",
        "stanza-create",
    )
    _run(
        "bash",
        "main-compose.sh",
        "exec",
        "-T",
        "--user",
        "postgres",
        "doglyad_database",
        "pgbackrest",
        "--stanza=doglyad_database",
        "check",
    )
    _run("bash", "main-compose.sh", "stop", "--timeout", "60", *SERVICES, timeout=300)
    # A failed backup or migration leaves writers stopped for inspection.
    _run("systemctl", "start", "doglyad-database-backup.service", timeout=7500)
    _run(
        "bash",
        "main-compose.sh",
        "run",
        "--rm",
        "--no-deps",
        "database_migrate",
        timeout=900,
    )
    _run("bash", "main-compose.sh", "up", "-d", "--no-deps", *SERVICES)
    _run("bash", "main-compose.sh", "up", "-d", "caddy")
    _run("systemctl", "enable", "--now", *TIMERS)
    _run("systemctl", "start", "doglyad-database-status.service", timeout=300)
    print(f"Main {environment}: database, migrations and backup timers initialized")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-config", action="store_true")
    arguments = parser.parse_args()
    try:
        if arguments.check_config:
            configure_main(ROOT, is_check_only=True)
        else:
            if (ROOT / ".infrastructure-update-lock").exists():
                raise RuntimeError(
                    "Inspect the existing deployment recovery lock before main setup"
                )
            with (ROOT / ".infrastructure-operation-lock").open("a") as operation:
                fcntl.flock(operation, fcntl.LOCK_EX | fcntl.LOCK_NB)
                configure_main(ROOT)
    except (
        OSError,
        ValueError,
        KeyError,
        configparser.Error,
        RuntimeError,
        subprocess.TimeoutExpired,
    ):
        print(
            "Configuration check failed; verify the selected profile, backup files and matching published release."
            if arguments.check_config
            else "Main setup failed; check configuration and services on the VM. Writers may remain stopped after a backup or migration failure.",
            file=sys.stderr,
        )
        sys.exit(1)
