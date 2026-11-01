from __future__ import annotations

import argparse
import os
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


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Start local PostgreSQL and apply billing migrations.",
    )
    parser.add_argument(
        "--stop",
        dest="is_stop",
        action="store_true",
        help="Stop PostgreSQL without deleting data.",
    )
    arguments = parser.parse_args()
    database = LocalBillingDatabase()
    try:
        if arguments.is_stop:
            database.stop()
        else:
            database.start()
    except (OSError, subprocess.CalledProcessError) as error:
        print(
            f"Local billing preparation failed: {error}",
            file=sys.stderr,
        )
        sys.exit(
            1,
        )
