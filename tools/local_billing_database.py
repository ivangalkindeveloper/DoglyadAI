from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
from pathlib import Path


class LocalBillingDatabase:
    ROOT = (
        Path(
            __file__,
        )
        .resolve()
        .parents[1]
    )
    URL = "postgresql+asyncpg://doglyad_local:doglyad_local_only@127.0.0.1:5433/billing"

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
                self.ROOT / "backend/main/docker-compose.local-billing.yml",
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
                "billing_database",
            ],
            cwd=self.ROOT,
            check=True,
        )
        environment = {
            **os.environ,
            "ENVIRONMENT": "development",
            "BILLING_DATABASE_URL": self.URL,
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
            "Local PostgreSQL is ready at 127.0.0.1:5433/billing; migrations are up to date.",
        )

    def stop(
        self,
    ) -> None:
        subprocess.run(
            [*self.compose, "stop", "billing_database"],
            cwd=self.ROOT,
            check=True,
        )
        print(
            "Local PostgreSQL stopped; data remains in doglyad-local-billing-data.",
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
            "Local billing database reset: all previous billing data has been removed.",
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
        description="Start local PostgreSQL and apply billing migrations.",
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
        help="Delete the local billing volume, recreate PostgreSQL and apply migrations.",
    )
    arguments = parser.parse_args()
    database = LocalBillingDatabase()
    try:
        if arguments.is_stop:
            database.stop()
        elif arguments.is_reset:
            database.reset()
        else:
            database.start()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(
            f"Local billing preparation failed: {error}",
            file=sys.stderr,
        )
        sys.exit(
            1,
        )
