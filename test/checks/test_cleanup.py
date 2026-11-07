from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from regression import cleanup, run_command


class CleanupTests(unittest.TestCase):
    def test_timeout_message_does_not_expose_launch_secrets(self):
        command = ["setenv", "AppCheckDebugToken", "private-debug-token"]
        with tempfile.TemporaryDirectory() as folder:
            with patch(
                "regression.subprocess.run",
                side_effect=subprocess.TimeoutExpired(command, 1),
            ):
                with self.assertRaises(RuntimeError) as raised:
                    run_command(command, Path(folder) / "device.log")
        self.assertNotIn("private-debug-token", str(raised.exception))

    def test_timeouts_do_not_skip_device_deletion_or_volume_cleanup(self):
        with tempfile.TemporaryDirectory() as folder:
            with patch(
                "regression.run_command",
                side_effect=[
                    subprocess.TimeoutExpired("shutdown", 60),
                    0,
                    subprocess.TimeoutExpired("logs", 60),
                    0,
                ],
            ) as run:
                self.assertTrue(
                    cleanup("owned-device", ["docker", "compose"], Path(folder), {})
                )
            self.assertEqual(run.call_count, 4)
            self.assertIn("delete", run.call_args_list[1].args[0])
            self.assertIn("--volumes", run.call_args_list[3].args[0])

    def test_failed_device_delete_still_cleans_volumes_and_fails_run(self):
        with tempfile.TemporaryDirectory() as folder:
            with patch("regression.run_command", side_effect=[0, 1, 0, 0]) as run:
                self.assertFalse(
                    cleanup("owned-device", ["docker", "compose"], Path(folder), {})
                )
            self.assertEqual(run.call_count, 4)

    def test_failed_volume_cleanup_cannot_publish(self):
        with tempfile.TemporaryDirectory() as folder:
            with patch(
                "regression.run_command",
                side_effect=[0, subprocess.TimeoutExpired("down", 120)],
            ):
                self.assertFalse(cleanup(None, ["docker", "compose"], Path(folder), {}))
