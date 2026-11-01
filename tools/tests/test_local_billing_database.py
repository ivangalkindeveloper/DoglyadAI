from __future__ import annotations

import json
import os
import subprocess
import unittest
from unittest.mock import patch

from tools.local_billing_database import LocalBillingDatabase


class LocalBillingDatabaseTests(unittest.TestCase):
    def test_database_health_precedes_migrations_and_local_url_overrides_environment(
        self,
    ) -> None:
        database = LocalBillingDatabase()
        with (
            patch.dict(
                os.environ,
                {
                    "ENVIRONMENT": "production",
                    "BILLING_DATABASE_URL": "remote-database",
                },
            ),
            patch(
                "tools.local_billing_database.subprocess.run",
            ) as run,
            patch(
                "builtins.print",
            ),
        ):
            database.start()
            self.assertEqual(
                os.environ["BILLING_DATABASE_URL"],
                "remote-database",
            )
        self.assertEqual(
            run.call_count,
            2,
        )
        start, migrate = run.call_args_list
        self.assertIn(
            "--wait",
            start.args[0],
        )
        self.assertIn(
            "--wait-timeout",
            start.args[0],
        )
        self.assertEqual(
            start.args[0][-1],
            "billing_database",
        )
        self.assertTrue(
            start.kwargs["check"],
        )
        self.assertEqual(
            migrate.args[0][-2:],
            ["upgrade", "head"],
        )
        self.assertEqual(
            migrate.kwargs["env"]["ENVIRONMENT"],
            "development",
        )
        self.assertEqual(
            migrate.kwargs["env"]["BILLING_DATABASE_URL"],
            database.URL,
        )
        self.assertTrue(
            migrate.kwargs["check"],
        )

    def test_database_failure_prevents_migrations(
        self,
    ) -> None:
        with (
            patch(
                "tools.local_billing_database.subprocess.run",
                side_effect=subprocess.CalledProcessError(
                    1,
                    "docker",
                ),
            ) as run,
            self.assertRaises(
                subprocess.CalledProcessError,
            ),
        ):
            LocalBillingDatabase().start()
        self.assertEqual(
            run.call_count,
            1,
        )

    def test_migration_failure_is_propagated(
        self,
    ) -> None:
        with (
            patch(
                "tools.local_billing_database.subprocess.run",
                side_effect=[
                    subprocess.CompletedProcess(
                        [],
                        0,
                    ),
                    subprocess.CalledProcessError(
                        1,
                        "alembic",
                    ),
                ],
            ) as run,
            self.assertRaises(
                subprocess.CalledProcessError,
            ),
        ):
            LocalBillingDatabase().start()
        self.assertEqual(
            run.call_count,
            2,
        )

    def test_stop_preserves_database_storage(
        self,
    ) -> None:
        with (
            patch(
                "tools.local_billing_database.subprocess.run",
            ) as run,
            patch(
                "builtins.print",
            ),
        ):
            LocalBillingDatabase().stop()
        self.assertEqual(
            run.call_args.args[0][-2:],
            ["stop", "billing_database"],
        )

    def test_debug_profile_uses_same_database_and_orders_preparation(
        self,
    ) -> None:
        def read_configuration(
            name: str,
        ) -> dict:
            source = (LocalBillingDatabase.ROOT / ".vscode" / name).read_text()
            return json.loads(
                "\n".join(
                    (
                        line
                        for line in source.splitlines()
                        if not line.lstrip().startswith(
                            "//",
                        )
                    ),
                ),
            )

        launch = read_configuration(
            "launch.json",
        )
        profile = next(
            (
                item
                for item in launch["configurations"]
                if item["name"] == "Backend: Local Mock"
            ),
        )
        self.assertEqual(
            profile["env"]["BILLING_DATABASE_URL"],
            LocalBillingDatabase.URL,
        )
        tasks = {
            item["label"]: item
            for item in read_configuration(
                "tasks.json",
            )["tasks"]
        }
        preparation = tasks[profile["preLaunchTask"]]
        self.assertEqual(
            preparation["dependsOrder"],
            "sequence",
        )
        self.assertEqual(
            preparation["dependsOn"],
            ["env: development", "billing: local"],
        )
        self.assertEqual(
            tasks["billing: local"]["args"],
            ["start-local-billing"],
        )


if __name__ == "__main__":
    unittest.main()
