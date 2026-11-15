from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class MainComposeTests(unittest.TestCase):
    def test_machine_and_selected_profile_override_the_calling_shell(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copyfile(
                Path(__file__).resolve().parents[1] / "main-compose.sh",
                root / "main-compose.sh",
            )
            (root / ".env").write_text(
                "TAG=machine-tag\nENV_FILE=secrets/.env.production\nDOMAIN=main.example\nDATABASE_IMAGE=pinned-image\n"
            )
            binary = root / "docker"
            binary.write_text(
                "#!"
                + str(Path(sys.executable).resolve())
                + "\nimport json,os,sys\nprint(json.dumps({'args':sys.argv[1:],'machine':{key:os.environ.get(key) for key in ('TAG','ENV_FILE','DOMAIN','DATABASE_IMAGE','DATABASE_URL','DATABASE_PASSWORD')}}))\n"
            )
            binary.chmod(0o755)
            result = subprocess.run(
                ["bash", str(root / "main-compose.sh"), "ps", "-q", "backend_main"],
                capture_output=True,
                text=True,
                check=True,
                env={
                    **os.environ,
                    "PATH": str(root) + os.pathsep + os.environ["PATH"],
                    "TAG": "wrong",
                    "ENV_FILE": "secrets/.env.development",
                    "DOMAIN": "wrong",
                    "DATABASE_IMAGE": "wrong",
                    "DATABASE_URL": "wrong",
                    "DATABASE_PASSWORD": "wrong",
                },
            )
            document = json.loads(result.stdout)
            self.assertEqual(
                document["args"][:7],
                [
                    "compose",
                    "--env-file",
                    ".env",
                    "--env-file",
                    "secrets/.env",
                    "--env-file",
                    "secrets/.env.production",
                ],
            )
            self.assertEqual(document["args"][-3:], ["ps", "-q", "backend_main"])
            self.assertEqual(
                document["machine"],
                {
                    "TAG": "machine-tag",
                    "ENV_FILE": "secrets/.env.production",
                    "DOMAIN": "main.example",
                    "DATABASE_IMAGE": "pinned-image",
                    "DATABASE_URL": None,
                    "DATABASE_PASSWORD": None,
                },
            )

    @unittest.skipUnless(
        shutil.which("docker"), "Docker Compose is required for stack validation"
    )
    def test_complete_stack_keeps_database_and_migrations_shared(self) -> None:
        source = Path(__file__).resolve().parents[1]
        for environment in ("development", "production"):
            with (
                self.subTest(environment=environment),
                tempfile.TemporaryDirectory() as directory,
            ):
                root = Path(directory)
                (root / "secrets").mkdir()
                (root / "secrets/.env").write_text("COMMON_FIXTURE=value\n")
                profile = root / f"secrets/.env.{environment}"
                profile.write_text("ENVIRONMENT=" + environment + "\n")
                variables = {
                    "TAG": "a" * 40,
                    "ENV_FILE": str(profile),
                    "DOMAIN": "main.example",
                    "DATABASE_IMAGE": "ghcr.io/ivangalkindeveloper/doglyad-database@sha256:"
                    + "b" * 64,
                    "DATABASE_URL": "postgresql+asyncpg://doglyad:synthetic@doglyad_database:5432/doglyad_database",
                    "DATABASE_PASSWORD": "synthetic",
                }
                command = [
                    "docker",
                    "compose",
                    "--project-directory",
                    str(root),
                    "-f",
                    str(source / "docker-compose.main.yml"),
                    "-f",
                    str(source / "docker-compose.database.yml"),
                    "config",
                    "--format",
                    "json",
                ]
                result = subprocess.run(
                    command,
                    env={**os.environ, **variables},
                    capture_output=True,
                    text=True,
                    check=True,
                )
                services = json.loads(result.stdout)["services"]
                self.assertEqual(
                    set(services),
                    {
                        "backend_main",
                        "report_worker",
                        "billing_gateway",
                        "billing_worker",
                        "database_migrate",
                        "doglyad_database",
                        "caddy",
                    },
                )
                for name in (
                    "backend_main",
                    "report_worker",
                    "billing_gateway",
                    "billing_worker",
                ):
                    service = services[name]
                    self.assertEqual(service["environment"]["ENVIRONMENT"], environment)
                    self.assertEqual(
                        service["environment"]["DATABASE_URL"],
                        variables["DATABASE_URL"],
                    )
                    self.assertEqual(
                        service["depends_on"]["database_migrate"]["condition"],
                        "service_completed_successfully",
                    )
                    self.assertFalse(service.get("ports"))
                self.assertFalse(services["doglyad_database"].get("ports"))
                self.assertEqual(
                    services["database_migrate"]["command"],
                    ["alembic", "upgrade", "head"],
                )
                self.assertEqual(
                    services["database_migrate"]["depends_on"]["doglyad_database"][
                        "condition"
                    ],
                    "service_healthy",
                )
                self.assertEqual(
                    services["caddy"]["volumes"][0]["source"], str(root / "Caddyfile")
                )

    def test_invalid_environment_cannot_invoke_compose(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copyfile(
                Path(__file__).resolve().parents[1] / "main-compose.sh",
                root / "main-compose.sh",
            )
            (root / ".env").write_text("ENV_FILE=../../other\n")
            result = subprocess.run(
                ["bash", str(root / "main-compose.sh"), "up"],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("explicit main environment", result.stderr)


if __name__ == "__main__":
    unittest.main()
