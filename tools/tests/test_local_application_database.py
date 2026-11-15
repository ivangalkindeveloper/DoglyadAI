from __future__ import annotations

import json
import os
import subprocess
import unittest
from unittest.mock import patch

from tools.local_application_database import LocalApplicationDatabase


class LocalApplicationDatabaseTests(unittest.TestCase):
    def test_database_health_precedes_migrations_and_local_url_overrides_environment(
        self,
    ) -> None:
        database = LocalApplicationDatabase()
        with (
            patch.dict(
                os.environ,
                {
                    "ENVIRONMENT": "production",
                    "DATABASE_URL": "remote-database",
                },
            ),
            patch(
                "tools.local_application_database.subprocess.run",
            ) as run,
            patch(
                "builtins.print",
            ),
        ):
            database.start()
            self.assertEqual(
                os.environ["DATABASE_URL"],
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
            "doglyad_database",
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
            migrate.kwargs["env"]["DATABASE_URL"],
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
                "tools.local_application_database.subprocess.run",
                side_effect=subprocess.CalledProcessError(
                    1,
                    "docker",
                ),
            ) as run,
            self.assertRaises(
                subprocess.CalledProcessError,
            ),
        ):
            LocalApplicationDatabase().start()
        self.assertEqual(
            run.call_count,
            1,
        )

    def test_migration_failure_is_propagated(
        self,
    ) -> None:
        with (
            patch(
                "tools.local_application_database.subprocess.run",
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
            LocalApplicationDatabase().start()
        self.assertEqual(
            run.call_count,
            2,
        )

    def test_stop_preserves_database_storage(
        self,
    ) -> None:
        with (
            patch(
                "tools.local_application_database.subprocess.run",
            ) as run,
            patch(
                "builtins.print",
            ),
        ):
            LocalApplicationDatabase().stop()
        self.assertEqual(
            run.call_args.args[0][-2:],
            ["stop", "doglyad_database"],
        )

    def test_debug_profile_uses_same_database_and_orders_preparation(
        self,
    ) -> None:
        def read_configuration(
            name: str,
        ) -> dict:
            source = (LocalApplicationDatabase.ROOT / ".vscode" / name).read_text()
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
            profile["env"]["DATABASE_URL"],
            LocalApplicationDatabase.URL,
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
            ["env: development", "database: local"],
        )
        self.assertEqual(
            tasks["database: local"]["args"],
            ["start-local-database"],
        )
        self.assertEqual(
            [item["name"] for item in launch["configurations"][:2]],
            ["Backend: Local Mock (Cold)", "Backend: Local Inference (Cold)"],
        )
        for name in ("Backend: Local Mock", "Backend: Local Inference"):
            ordinary_profile = next(
                (item for item in launch["configurations"] if item["name"] == name),
            )
            cold_profile = next(
                (
                    item
                    for item in launch["configurations"]
                    if item["name"] == name + " (Cold)"
                ),
            )
            self.assertEqual(
                cold_profile["env"],
                ordinary_profile["env"],
            )
            self.assertEqual(
                ordinary_profile["preLaunchTask"],
                "backend: local preparation",
            )
            cold_preparation = tasks[cold_profile["preLaunchTask"]]
            self.assertEqual(
                cold_preparation["dependsOrder"],
                "sequence",
            )
            self.assertEqual(
                cold_preparation["dependsOn"],
                ["env: development", "database: clean local"],
            )
        self.assertEqual(
            tasks["database: clean local"]["args"],
            ["reset-local-database"],
        )

    def test_reset_deletes_only_local_volume_before_start_and_migrations(
        self,
    ) -> None:
        database = LocalApplicationDatabase()
        with (
            patch.object(
                database,
                "require_local_docker",
            ),
            patch(
                "tools.local_application_database.socket.create_connection",
                side_effect=ConnectionRefusedError,
            ),
            patch.dict(
                os.environ,
                {"ENVIRONMENT": "production", "DATABASE_URL": "remote"},
            ),
            patch(
                "tools.local_application_database.subprocess.run",
            ) as run,
            patch(
                "builtins.print",
            ),
        ):
            database.reset()
        self.assertEqual(
            run.call_count,
            3,
        )
        destroy, start, migrate = run.call_args_list
        self.assertEqual(
            destroy.args[0],
            [*database.compose, "down", "--volumes"],
        )
        self.assertIn(
            "docker-compose.local-database.yml",
            " ".join(
                destroy.args[0],
            ),
        )
        self.assertEqual(
            destroy.kwargs["cwd"],
            database.ROOT,
        )
        self.assertTrue(
            destroy.kwargs["check"],
        )
        self.assertIn(
            "--wait",
            start.args[0],
        )
        self.assertEqual(
            migrate.kwargs["env"]["ENVIRONMENT"],
            "development",
        )
        self.assertEqual(
            migrate.kwargs["env"]["DATABASE_URL"],
            database.URL,
        )

    def test_live_backend_prevents_reset(
        self,
    ) -> None:
        database = LocalApplicationDatabase()
        with (
            patch.object(
                database,
                "require_local_docker",
            ),
            patch(
                "tools.local_application_database.socket.create_connection",
            ),
            patch(
                "tools.local_application_database.subprocess.run",
            ) as run,
            self.assertRaisesRegex(
                RuntimeError,
                "Stop the backend",
            ),
        ):
            database.reset()
        run.assert_not_called()

    def test_failed_volume_removal_prevents_start_and_migrations(
        self,
    ) -> None:
        database = LocalApplicationDatabase()
        with (
            patch.object(
                database,
                "require_local_docker",
            ),
            patch(
                "tools.local_application_database.socket.create_connection",
                side_effect=ConnectionRefusedError,
            ),
            patch(
                "tools.local_application_database.subprocess.run",
                side_effect=subprocess.CalledProcessError(
                    1,
                    "docker",
                ),
            ) as run,
            self.assertRaises(
                subprocess.CalledProcessError,
            ),
        ):
            database.reset()
        self.assertEqual(
            run.call_count,
            1,
        )

    def test_remote_docker_host_is_rejected_before_any_command(
        self,
    ) -> None:
        with (
            patch.dict(
                os.environ,
                {"DOCKER_HOST": "tcp://remote:2376"},
            ),
            patch(
                "tools.local_application_database.subprocess.run",
            ) as run,
            self.assertRaisesRegex(
                RuntimeError,
                "local Docker",
            ),
        ):
            LocalApplicationDatabase().reset()
        run.assert_not_called()

    def test_remote_docker_context_is_rejected_before_database_reset(
        self,
    ) -> None:
        with (
            patch.dict(
                os.environ,
                {"DOCKER_HOST": ""},
            ),
            patch(
                "tools.local_application_database.subprocess.run",
                return_value=subprocess.CompletedProcess(
                    [],
                    0,
                    stdout="ssh://remote\n",
                ),
            ) as run,
            self.assertRaisesRegex(
                RuntimeError,
                "remote Docker context",
            ),
        ):
            LocalApplicationDatabase().reset()
        self.assertEqual(
            run.call_count,
            1,
        )
        self.assertEqual(
            run.call_args.args[0][:3],
            ["docker", "context", "inspect"],
        )


if __name__ == "__main__":
    unittest.main()
