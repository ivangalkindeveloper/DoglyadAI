from __future__ import annotations

import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import update_remote as remote


class RemoteTransactionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.cwd = Path.cwd()
        self.addCleanup(os.chdir, self.cwd)
        self.root = Path(self.directory.name)
        self.root_patch = patch.object(remote, "ROOT", self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        (self.root / ".env").write_text(
            "TAG=old\nENV_FILE=secrets/.env.production\nDOMAIN=example.com\n"
        )
        (self.root / "docker-compose.yml").write_text("services: {}\n")
        os.chdir(self.root)
        self.release = "a" * 32
        self.target = {"role": "production", "ssh": "main"}
        self.state = {"image": "sha256:" + "b" * 64, "companion": "caddy-id"}

    def action(self, action: str, **kwargs: object) -> dict:
        return remote.main(
            dict(action=action, release=self.release, target=self.target, **kwargs)
        )

    def test_rollback_restores_env_and_pins_previous_image_id(self) -> None:
        original = (self.root / ".env").read_bytes()
        with patch.object(remote, "check", return_value=self.state):
            self.action("prepare")
        image = "ghcr.io/ivangalkindeveloper/doglyad-main@sha256:" + "c" * 64
        with (
            patch.object(remote, "run", return_value=json.dumps([{"Id": "new-image"}])),
            patch.object(remote, "compose"),
            patch.object(remote, "wait_ready", return_value={}),
        ):
            self.action("update", image=image, sha="d" * 40)
            self.assertIn("@sha256:", (self.root / ".env").read_text())
            self.action("rollback")
        self.assertEqual((self.root / ".env").read_bytes(), original)
        override = json.loads(
            (self.root / f".deploy-{self.release}/rollback.json").read_text()
        )
        self.assertEqual(
            override["services"]["backend_main"]["image"], self.state["image"]
        )

    def test_foreign_release_cannot_unlock(self) -> None:
        with patch.object(remote, "check", return_value=self.state):
            self.action("prepare")
        self.release = "e" * 32
        with self.assertRaisesRegex(RuntimeError, "another release"):
            self.action("unlock")
        self.assertTrue((self.root / ".infrastructure-update-lock").exists())

    def test_environment_mismatch_fails_before_request(self) -> None:
        running = {"State": {"Running": True}}
        with (
            patch.object(remote, "container", return_value=running),
            patch.object(remote, "compose"),
            patch.object(remote, "http") as http,
        ):
            with self.assertRaisesRegex(RuntimeError, "environment"):
                remote.check({"role": "development"})
        http.assert_not_called()


if __name__ == "__main__":
    unittest.main()
