from __future__ import annotations

import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import update_infrastructure as update


class DeploymentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.targets = [
            {"role": "inference", "ssh": "gpu", "model": "model"},
            {"role": "development", "ssh": "dev"},
            {"role": "production", "ssh": "prod"},
        ]

    def test_inventory_rejects_missing_production_and_ssh_injection(self) -> None:
        for targets in (
            self.targets[:-1],
            [dict(self.targets[0], ssh="gpu; touch bad"), *self.targets[1:]],
        ):
            with patch.object(
                Path, "read_text", return_value=json.dumps({"targets": targets})
            ):
                with self.assertRaises(ValueError):
                    update.inventory(Path("unused"))

    def test_success_orders_inference_before_main(self) -> None:
        calls = []

        def remote(target: dict, action: str, *args: object, **kwargs: object) -> dict:
            calls.append((target["ssh"], action))
            return {"image": "digest"}

        with patch.object(update, "remote", side_effect=remote):
            update.rollout(
                self.targets, "release", {"main": "image", "inference": "image"}, "sha"
            )
        self.assertEqual(
            [host for host, action in calls if action == "update"],
            ["gpu", "dev", "prod"],
        )
        self.assertFalse(any(action == "rollback" for _, action in calls))

    def test_failure_rolls_back_attempted_hosts_in_reverse(self) -> None:
        calls = []

        def remote(target: dict, action: str, *args: object, **kwargs: object) -> dict:
            calls.append((target["ssh"], action))
            if target["ssh"] == "dev" and action == "update":
                raise RuntimeError("SSH lost after update")
            return {"image": "digest"}

        with patch.object(update, "remote", side_effect=remote):
            with self.assertRaises(RuntimeError):
                update.rollout(
                    self.targets,
                    "release",
                    {"main": "image", "inference": "image"},
                    "sha",
                )
        self.assertEqual(
            [host for host, action in calls if action == "rollback"], ["dev", "gpu"]
        )
        self.assertNotIn(("prod", "update"), calls)

    def test_manifest_pins_amd64_digest(self) -> None:
        manifest = [
            {
                "Descriptor": {
                    "platform": {"os": "linux", "architecture": "amd64"},
                    "digest": "sha256:" + "a" * 64,
                }
            }
        ]
        with patch.object(update, "command", return_value=json.dumps(manifest)):
            self.assertEqual(
                update.amd64_image("main", "sha"),
                update.REGISTRY + "main@sha256:" + "a" * 64,
            )

    def test_branch_race_does_not_deploy(self) -> None:
        responses = [
            {"sha": "original"},
            [{"displayTitle": "Backend images unique", "headSha": "new"}],
        ]
        with (
            patch.object(update, "github", side_effect=responses),
            patch.object(update, "command"),
            patch.object(update.uuid, "uuid4") as unique,
        ):
            unique.return_value.hex = "unique"
            with self.assertRaisesRegex(RuntimeError, "Branch advanced"):
                update.build("master", 10)

    def test_failed_build_does_not_return_a_release(self) -> None:
        responses = [
            {"sha": "sha"},
            [
                {
                    "displayTitle": "Backend images unique",
                    "headSha": "sha",
                    "databaseId": 1,
                    "url": "run-url",
                }
            ],
            {
                "status": "completed",
                "conclusion": "failure",
                "headSha": "sha",
                "jobs": [],
            },
        ]
        with (
            patch.object(update, "github", side_effect=responses),
            patch.object(update, "command"),
            patch.object(update.uuid, "uuid4") as unique,
        ):
            unique.return_value.hex = "unique"
            with self.assertRaisesRegex(RuntimeError, "Both image jobs"):
                update.build("master", 10)


if __name__ == "__main__":
    unittest.main()
