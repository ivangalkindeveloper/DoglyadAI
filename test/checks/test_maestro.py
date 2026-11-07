from pathlib import Path
import os
import socket
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from regression import maestro_driver_port, maestro_executable
from artifacts import flow_commands


class MaestroDiscoveryTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.home = Path(directory.name)
        self.standard = self.home / ".maestro/bin/maestro"
        self.standard.parent.mkdir(parents=True)
        self.standard.write_text("#!/bin/sh\nexit 0\n")
        self.standard.chmod(0o700)
        for context in (
            patch("regression.Path.home", return_value=self.home),
            patch.dict(os.environ, {"PATH": ""}),
        ):
            context.start()
            self.addCleanup(context.stop)

    def test_standard_installation_is_found_without_path_entry(self):
        self.assertEqual(maestro_executable(), str(self.standard))

    def test_path_installation_has_priority(self):
        custom = self.home / "custom"
        custom.mkdir()
        executable = custom / "maestro"
        executable.write_text("#!/bin/sh\nexit 0\n")
        executable.chmod(0o700)
        os.environ["PATH"] = str(custom)
        self.assertEqual(maestro_executable(), str(executable.resolve()))

    def test_nonexecutable_download_is_not_accepted(self):
        self.standard.chmod(0o600)
        with self.assertRaisesRegex(ValueError, r"PATH or ~/.maestro/bin/maestro"):
            maestro_executable()

    def test_missing_installation_explains_both_search_locations(self):
        self.standard.unlink()
        with self.assertRaisesRegex(ValueError, r"PATH or ~/.maestro/bin/maestro"):
            maestro_executable()


class MaestroPortTests(unittest.TestCase):
    def test_busy_listener_is_preserved_and_another_port_can_be_bound(self):
        first = maestro_driver_port(22087)
        with socket.socket() as occupied:
            occupied.bind(("0.0.0.0", first))
            occupied.listen()
            selected = maestro_driver_port(first)
            self.assertGreater(selected, first)
            self.assertLess(selected, 32768)
            with socket.socket() as available:
                available.bind(("0.0.0.0", selected))
            self.assertEqual(occupied.getsockname()[1], first)

    def test_exhausted_range_does_not_fall_back_to_ephemeral_ports(self):
        with self.assertRaisesRegex(RuntimeError, "No free Maestro driver port"):
            maestro_driver_port(32768)


class MaestroLaunchArgumentTests(unittest.TestCase):
    def test_booleans_and_numbers_cannot_silently_skip_user_defaults_flags(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "flow.yaml"
            with patch("artifacts.TEST", root):
                for value in ["true", "false", "0", "1"]:
                    with self.subTest(value=value):
                        path.write_text(
                            "appId: local\n---\n- launchApp:\n    arguments:\n      flag: "
                            + value
                            + "\n"
                        )
                        with self.assertRaisesRegex(
                            ValueError, "arguments must be strings"
                        ):
                            flow_commands(path)
                path.write_text(
                    "appId: local\n---\n- launchApp:\n    arguments:\n      flag: 'true'\n"
                )
                self.assertEqual(len(flow_commands(path)), 1)
