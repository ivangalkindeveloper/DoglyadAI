from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
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

    def test_stage_prepares_storage_before_new_image_validation(self) -> None:
        with patch.object(remote, "check", return_value=self.state):
            self.action("prepare")
        image = "ghcr.io/ivangalkindeveloper/doglyad-main@sha256:" + "c" * 64
        with patch.object(remote, "run", return_value="") as run:
            self.action(
                "stage", image=image, models=[], storage_script="storage fixture"
            )
        calls = run.call_args_list
        self.assertEqual(calls[0].args[:2], ("docker", "pull"))
        preparation = calls[1]
        self.assertIn("0:0", preparation.args)
        self.assertIn(f"{self.root}/secrets:/storage/secrets:rw", preparation.args)
        self.assertEqual(preparation.kwargs["input_text"], "storage fixture")
        self.assertIn(f"{self.root}/secrets:/app/secrets:ro", calls[2].args)

    def test_new_running_root_container_fails_readiness(self) -> None:
        state = {
            "container": "backend",
            "image": "image",
            "companion": "caddy",
            "restarts": 0,
        }
        with (
            patch.object(remote, "check", return_value=state),
            patch.object(remote, "run", return_value="0"),
            patch.object(remote.time, "sleep"),
            self.assertRaises(RuntimeError),
        ):
            remote.wait_ready(self.target, "image", "caddy", is_non_root_required=True)

    def test_new_non_root_container_passes_readiness(self) -> None:
        state = {
            "container": "backend",
            "image": "image",
            "companion": "caddy",
            "restarts": 0,
        }
        with (
            patch.object(remote, "check", return_value=state),
            patch.object(remote, "run", return_value="10001") as run,
            patch.object(remote.time, "sleep"),
        ):
            self.assertEqual(
                remote.wait_ready(
                    self.target, "image", "caddy", is_non_root_required=True
                ),
                state,
            )
        run.assert_called_once_with("docker", "exec", "backend", "id", "-u")


if __name__ == "__main__":
    unittest.main()
