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

    def test_report_worker_updates_and_rolls_back_with_api(self) -> None:
        self.state["report_worker"] = {"container": "worker", "image": self.state["image"], "restarts": 0}
        with patch.object(remote, "check", return_value=self.state):
            self.action("prepare")
        image = "ghcr.io/ivangalkindeveloper/doglyad-main@sha256:" + "c" * 64
        with (patch.object(remote, "run", return_value=json.dumps([{"Id": "new-image"}])) as run,
              patch.object(remote, "compose") as compose,
              patch.object(remote, "wait_ready", return_value={})):
            self.action("update", image=image, sha="d" * 40)
            self.assertIn("report_worker", compose.call_args_list[-1].args)
            self.action("rollback")
            self.assertIn("report_worker", run.call_args_list[-1].args)
        override = json.loads((self.root / f".deploy-{self.release}/rollback.json").read_text())
        self.assertEqual(override["services"]["report_worker"]["image"], self.state["image"])

    def test_foreign_release_cannot_unlock(self) -> None:
        with patch.object(remote, "check", return_value=self.state):
            self.action("prepare")
        self.release = "e" * 32
        with self.assertRaisesRegex(RuntimeError, "another release"):
            self.action("unlock")
        self.assertTrue((self.root / ".infrastructure-update-lock").exists())

    def prepare_multi_host(self) -> bytes:
        (self.root / ".env").write_text(
            "INFERENCE_BACKEND_IMAGE=sha256:" + "a" * 64 + "\n"
        )
        (self.root / "profile.json").write_text('{"version":1}')
        (self.root / "config").mkdir()
        (self.root / "config/server.json").write_text("{}")
        self.target = {
            "role": "inference",
            "ssh": "gpu",
            "architecture": "arm64",
            "models": {"model/a": "engine_a", "model/b": "engine_b"},
            "profile_fingerprint": "a" * 64,
        }
        self.state["companion"] = {
            name: {"id": name, "image": "vllm", "restarts": 0}
            for name in ["engine_a", "engine_b"]
        }
        with patch.object(remote, "check", return_value=self.state):
            self.action("prepare")
        return (self.root / ".env").read_bytes()

    def test_multi_model_update_and_recovery_preserve_all_engine_snapshots(
        self,
    ) -> None:
        original = self.prepare_multi_host()
        image = "ghcr.io/ivangalkindeveloper/doglyad-inference@sha256:" + "c" * 64
        with (
            patch.object(
                remote, "run", return_value=json.dumps([{"Id": "new-image"}])
            ) as run,
            patch.object(remote, "compose") as compose,
            patch.object(remote, "wait_ready", return_value={}) as ready,
        ):
            self.action("update", image=image, sha="d" * 40)
            # Recovery can use the stored normalized profile target, without a local profile file.
            self.target = {"role": "inference", "ssh": "gpu"}
            self.action("rollback")
        self.assertEqual((self.root / ".env").read_bytes(), original)
        for call in ready.call_args_list:
            self.assertEqual(call.args[2], self.state["companion"])
            self.assertEqual(len(call.args[0]["models"]), 2)
        starts = [call.args for call in compose.call_args_list if call.args[0] == "up"]
        self.assertEqual(len(starts), 1)
        self.assertEqual(starts[0][-1], "backend_inference")
        self.assertIn("--no-deps", starts[0])
        rollback = run.call_args_list[-1].args
        self.assertEqual(rollback[-1], "backend_inference")
        self.assertIn("--no-deps", rollback)

    def test_changed_host_profile_blocks_update_and_rollback_before_mutation(
        self,
    ) -> None:
        original = self.prepare_multi_host()
        (self.root / "profile.json").write_text('{"version":2}')
        with (
            patch.object(remote, "run") as run,
            patch.object(remote, "compose") as compose,
        ):
            for action in ["update", "rollback"]:
                with self.assertRaisesRegex(RuntimeError, "configuration changed"):
                    self.action(action)
            run.assert_not_called()
            compose.assert_not_called()
        self.assertEqual((self.root / ".env").read_bytes(), original)

    def test_published_release_replaces_local_spark_image_and_rollback_restores_it(
        self,
    ) -> None:
        original = "INFERENCE_BACKEND_IMAGE=sha256:" + "a" * 64 + "\n"
        (self.root / ".env").write_text(original)
        with patch.object(remote, "check", return_value=self.state):
            self.action("prepare")
        image = "ghcr.io/ivangalkindeveloper/doglyad-inference@sha256:" + "c" * 64
        with (
            patch.object(remote, "run", return_value=json.dumps([{"Id": "new-image"}])),
            patch.object(remote, "compose"),
            patch.object(remote, "wait_ready", return_value={}),
        ):
            self.action("update", image=image, sha="d" * 40)
            self.assertIn(
                f"INFERENCE_BACKEND_IMAGE={image}\n", (self.root / ".env").read_text()
            )
            self.action("rollback")
        self.assertEqual((self.root / ".env").read_text(), original)

    def test_environment_mismatch_fails_before_request(self) -> None:
        running = {"State": {"Running": True}}
        with (
            patch.object(remote, "container", return_value=running),
            patch.object(remote, "run", return_value="x86_64"),
            patch.object(remote, "compose"),
            patch.object(remote, "http") as http,
        ):
            with self.assertRaisesRegex(RuntimeError, "environment"):
                remote.check({"role": "development"})
        http.assert_not_called()

    def test_architecture_mismatch_fails_before_compose(self) -> None:
        with (
            patch.object(remote, "run", return_value="aarch64"),
            patch.object(remote, "compose") as compose,
        ):
            with self.assertRaisesRegex(RuntimeError, "architecture"):
                remote.check({"role": "inference", "architecture": "amd64"})
        compose.assert_not_called()

    def test_dgx_directory_selects_its_own_storage(self) -> None:
        self.target = {
            "role": "inference",
            "ssh": "spark",
            "model": "model",
            "architecture": "arm64",
            "directory": "/opt/doglyad/medgemma-4b",
        }
        with (
            patch.object(remote.os, "chdir") as chdir,
            patch.object(remote, "check", return_value=self.state),
        ):
            self.action("prepare")
        chdir.assert_called_once_with(Path(self.target["directory"]))
        image = "ghcr.io/ivangalkindeveloper/doglyad-inference@sha256:" + "c" * 64
        with (
            patch.object(remote.os, "chdir"),
            patch.object(remote, "run", return_value="") as run,
        ):
            self.action("stage", image=image, models=[], storage_script="fixture")
        self.assertIn(
            "/opt/doglyad/medgemma-4b/secrets:/storage/secrets:rw",
            run.call_args_list[1].args,
        )
        self.assertIn(
            "/opt/doglyad/medgemma-4b/logs:/storage/logs:rw", run.call_args_list[1].args
        )

    def test_invalid_stack_directory_does_not_change_working_directory(self) -> None:
        self.target["directory"] = "/opt/doglyad/../other"
        with patch.object(remote.os, "chdir") as chdir:
            with self.assertRaisesRegex(ValueError, "directory"):
                self.action("check")
        chdir.assert_not_called()

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
