from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from regression import run_command, start_environment


class EnvironmentTests(unittest.TestCase):
    def test_build_uses_its_timeout_and_start_does_not_rebuild(self):
        compose = ["docker", "compose", "--project-name", "isolated"]
        env = {"EXAMPLE": "value"}
        with patch("regression.required") as required:
            start_environment(compose, Path("run"), env, 7200)
        self.assertEqual(required.call_count, 2)
        build, start = required.call_args_list
        self.assertEqual(build.args[0], [*compose, "build"])
        self.assertEqual(build.kwargs["timeout"], 7200)
        self.assertEqual(build.kwargs["env"], env)
        self.assertEqual(start.args[0], [*compose, "up", "--no-build", "-d"])
        self.assertNotIn("timeout", start.kwargs)

    def test_failed_build_does_not_start_containers(self):
        with patch(
            "regression.required", side_effect=RuntimeError("build failed")
        ) as required:
            with self.assertRaisesRegex(RuntimeError, "build failed"):
                start_environment(["docker", "compose"], Path("run"), {}, 3600)
        self.assertEqual(required.call_count, 1)

    def test_progress_shows_activity_without_arguments_or_log_contents(self):
        messages = []
        heartbeat = threading.Event()

        def capture(*values, **kwargs):
            message = " ".join(str(value) for value in values)
            messages.append(message)
            if "elapsed" in message:
                heartbeat.set()

        def complete(command, **kwargs):
            kwargs["stdout"].write("private-log-token\n")
            kwargs["stdout"].flush()
            self.assertTrue(heartbeat.wait(2), "No progress while command was running")
            return subprocess.CompletedProcess(command, 0)

        with tempfile.TemporaryDirectory() as directory:
            with (
                patch("regression.PROGRESS_INTERVAL_SECONDS", 0.01),
                patch("regression.subprocess.run", side_effect=complete),
                patch("builtins.print", side_effect=capture),
            ):
                result = run_command(
                    ["builder", "private-command-token"],
                    Path(directory) / "build.log",
                    timeout=3600,
                    progress="Building backend images",
                )
            self.assertEqual(result, 0)
            self.assertIn(
                "private-log-token", (Path(directory) / "build.log").read_text()
            )
        output = "\n".join(messages)
        self.assertIn("timeout: 3600s", output)
        self.assertIn("last update", output)
        self.assertIn("exit code: 0", output)
        self.assertNotIn("private-command-token", output)
        self.assertNotIn("private-log-token", output)

    def test_progress_stops_on_timeout_without_exposing_arguments(self):
        command = ["builder", "private-command-token"]
        with tempfile.TemporaryDirectory() as directory:
            with (
                patch(
                    "regression.subprocess.run",
                    side_effect=subprocess.TimeoutExpired(command, 3600),
                ),
                patch("builtins.print") as output,
            ):
                with self.assertRaisesRegex(RuntimeError, "after 3600s") as error:
                    run_command(
                        command,
                        Path(directory) / "build.log",
                        timeout=3600,
                        progress="Build",
                    )
        self.assertNotIn("private-command-token", str(error.exception))
        self.assertNotIn("private-command-token", str(output.call_args_list))
