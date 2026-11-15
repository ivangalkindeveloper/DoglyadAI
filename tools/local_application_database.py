from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
from pathlib import Path


class LocalApplicationDatabase:
    ROOT = (
        Path(
            __file__,
        )
        .resolve()
        .parents[1]
    )
    URL = "postgresql+asyncpg://doglyad_local:doglyad_local_only@127.0.0.1:5433/doglyad_database"

    def __init__(
        self,
    ) -> None:
        pass

    @property
    def compose(
        self,
    ) -> list[str]:
        return [
            "docker",
            "compose",
            "--env-file",
            os.devnull,
            "-f",
            str(
                self.ROOT / "backend/main/docker-compose.local-database.yml",
            ),
        ]

    def start(
        self,
    ) -> None:
        subprocess.run(
            [
                *self.compose,
                "up",
                "--detach",
                "--wait",
                "--wait-timeout",
                "60",
                "doglyad_database",
            ],
            cwd=self.ROOT,
            check=True,
        )
        environment = {
            **os.environ,
            "ENVIRONMENT": "development",
            "DATABASE_URL": self.URL,
        }
        subprocess.run(
            [
                sys.executable,
                "-m",
                "alembic",
                "-c",
                str(
                    self.ROOT / "backend/main/alembic.ini",
                ),
                "upgrade",
                "head",
            ],
            cwd=self.ROOT,
            env=environment,
            check=True,
        )
        print(
            "Local PostgreSQL is ready at 127.0.0.1:5433/doglyad_database; migrations are up to date.",
        )

    def stop(
        self,
    ) -> None:
        subprocess.run(
            [*self.compose, "stop", "doglyad_database"],
            cwd=self.ROOT,
            check=True,
        )
        print(
            "Local PostgreSQL stopped; data remains in doglyad-local-database-data.",
        )

    def reset(
        self,
    ) -> None:
        self.require_local_docker()
        try:
            with socket.create_connection(
                ("127.0.0.1", 8000),
                timeout=0.5,
            ):
                pass
        except ConnectionRefusedError:
            pass
        else:
            raise RuntimeError(
                "Stop the backend listening on port 8000 before resetting the local database.",
            )
        subprocess.run(
            [*self.compose, "down", "--volumes"],
            cwd=self.ROOT,
            check=True,
        )
        self.start()
        print(
            "Local application database reset: all previous application data has been removed.",
        )

    def require_local_docker(
        self,
    ) -> None:
        override = os.environ.get(
            "DOCKER_HOST",
        )
        if override and not override.startswith(
            "unix://",
        ):
            raise RuntimeError(
                "Local database reset requires a local Docker Unix socket.",
            )
        result = subprocess.run(
            ["docker", "context", "inspect", "--format", "{{.Endpoints.docker.Host}}"],
            capture_output=True,
            text=True,
            check=True,
        )
        if not result.stdout.strip().startswith(
            "unix://",
        ):
            raise RuntimeError(
                "Refusing to reset a database through a remote Docker context.",
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Start local PostgreSQL and apply application migrations.",
    )
    operation = parser.add_mutually_exclusive_group()
    operation.add_argument(
        "--stop",
        dest="is_stop",
        action="store_true",
        help="Stop PostgreSQL without deleting data.",
    )
    operation.add_argument(
        "--reset",
        dest="is_reset",
        action="store_true",
        help="Delete the local database volume, recreate PostgreSQL and apply migrations.",
    )
    arguments = parser.parse_args()
    database = LocalApplicationDatabase()
    try:
        if arguments.is_stop:
            database.stop()
        elif arguments.is_reset:
            database.reset()
        else:
            database.start()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(
            f"Local database preparation failed: {error}",
            file=sys.stderr,
        )
        sys.exit(
            1,
        )
