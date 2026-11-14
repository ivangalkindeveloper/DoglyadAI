from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
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

    def test_profile_expands_one_host_into_all_models(self) -> None:
        path = Path(update.__file__).parent / "inference/profiles/dgx-spark.json"
        target = {
            "role": "inference",
            "ssh": "spark",
            "directory": "/opt/doglyad/inference",
            "profile": str(path),
        }
        original_read = Path.read_text

        def read(file: Path, *args: object, **kwargs: object) -> str:
            if file.name == "inventory-fixture.json":
                return json.dumps({"targets": [target, *self.targets[1:]]})
            return original_read(file, *args, **kwargs)

        with patch.object(Path, "read_text", read):
            targets = update.inventory(Path("inventory-fixture.json"))
        self.assertEqual(len(targets), 3)
        self.assertEqual(targets[0]["architecture"], "arm64")
        self.assertEqual(len(targets[0]["models"]), 5)
        self.assertEqual(len(targets[0]["profile_fingerprint"]), 64)
        calls = []
        with (
            patch.object(sys, "argv", ["update", "--check"]),
            patch.object(update, "inventory", return_value=targets),
            patch.object(
                update,
                "remote",
                side_effect=lambda t, a, *args, **kwargs: calls.append(
                    (t["ssh"], a, kwargs)
                )
                or {"image": "digest"},
            ),
        ):
            self.assertEqual(update.main(), 0)
        self.assertEqual(
            [host for host, action, _ in calls if action == "check"],
            ["spark", "dev", "prod"],
        )
        for _, action, arguments in calls:
            if action == "routes":
                self.assertEqual(set(arguments["models"]), set(targets[0]["models"]))

    def test_inventory_rejects_ambiguous_profile_and_duplicate_model_hosts(
        self,
    ) -> None:
        path = Path(update.__file__).parent / "inference/profiles/dgx-spark.json"
        base = {"role": "inference", "ssh": "spark", "profile": str(path)}
        original_read = Path.read_text
        for entries in (
            [dict(base, model="extra")],
            [dict(base, architecture="amd64")],
            [base, dict(base, ssh="second")],
        ):
            with self.subTest(entries=entries):

                def read(file: Path, *args: object, **kwargs: object) -> str:
                    if file.name == "inventory-fixture.json":
                        return json.dumps({"targets": [*entries, *self.targets[1:]]})
                    return original_read(file, *args, **kwargs)

                with (
                    patch.object(Path, "read_text", read),
                    self.assertRaises(ValueError),
                ):
                    update.inventory(Path("inventory-fixture.json"))

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
                self.targets,
                "release",
                {("main", "amd64"): "image", ("inference", "amd64"): "image"},
                "sha",
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
                    {("main", "amd64"): "image", ("inference", "amd64"): "image"},
                    "sha",
                )
        self.assertEqual(
            [host for host, action in calls if action == "rollback"], ["dev", "gpu"]
        )
        self.assertNotIn(("prod", "update"), calls)

    def test_main_scope_keeps_model_coverage_and_never_contacts_gpu(self) -> None:
        calls: list[tuple[str, str, dict]] = []

        def remote(target: dict, action: str, *args: object, **kwargs: object) -> dict:
            calls.append((target["ssh"], action, kwargs))
            return {"image": "digest"}

        with (
            patch.object(sys, "argv", ["update", "--scope", "main"]),
            patch.object(update, "inventory", return_value=self.targets),
            patch.object(update, "remote", side_effect=remote),
            patch.object(update, "build", return_value=("sha", "run-url")),
            patch.object(update, "platform_image", return_value="image") as image,
        ):
            self.assertEqual(update.main(), 0)
        self.assertEqual({host for host, _, _ in calls}, {"dev", "prod"})
        self.assertFalse(any(action == "routes" for _, action, _ in calls))
        self.assertEqual(
            [(host, action) for host, action, _ in calls],
            [
                ("dev", "check"),
                ("prod", "check"),
                ("dev", "prepare"),
                ("prod", "prepare"),
                ("dev", "stage"),
                ("prod", "stage"),
                ("dev", "update"),
                ("prod", "update"),
                ("prod", "unlock"),
                ("dev", "unlock"),
            ],
        )
        for _, action, kwargs in calls:
            if action == "stage":
                self.assertEqual(kwargs["models"], ["model"])
        image.assert_called_once_with("main", "sha", "amd64")

    def test_main_scope_preflight_never_builds_or_checks_inference(self) -> None:
        with (
            patch.object(sys, "argv", ["update", "--scope", "main", "--check"]),
            patch.object(update, "inventory", return_value=self.targets),
            patch.object(update, "remote", return_value={"image": "digest"}) as remote,
            patch.object(update, "build") as build,
        ):
            self.assertEqual(update.main(), 0)
        self.assertEqual(remote.call_count, 2)
        self.assertEqual(
            [(call.args[0]["ssh"], call.args[1]) for call in remote.call_args_list],
            [("dev", "check"), ("prod", "check")],
        )
        build.assert_not_called()

    def test_main_scope_failure_rolls_back_both_main_hosts(self) -> None:
        calls: list[tuple[str, str]] = []

        def remote(target: dict, action: str, *args: object, **kwargs: object) -> dict:
            calls.append((target["ssh"], action))
            if target["ssh"] == "prod" and action == "update":
                raise RuntimeError("SSH lost after production update")
            return {"image": "digest"}

        with (
            patch.object(sys, "argv", ["update", "--scope", "main"]),
            patch.object(update, "inventory", return_value=self.targets),
            patch.object(update, "remote", side_effect=remote),
            patch.object(update, "build", return_value=("sha", "run-url")),
            patch.object(update, "platform_image", return_value="image"),
        ):
            with self.assertRaises(RuntimeError):
                update.main()
        self.assertEqual(
            [host for host, action in calls if action == "rollback"], ["prod", "dev"]
        )
        self.assertFalse(any(action in {"unlock", "routes"} for _, action in calls))
        self.assertNotIn("gpu", [host for host, _ in calls])

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
                update.platform_image("main", "sha", "amd64"),
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
            with self.assertRaisesRegex(
                RuntimeError, "All checks and image publication jobs"
            ):
                update.build("master", 10)

    def test_three_models_can_share_one_arm64_host_in_distinct_directories(
        self,
    ) -> None:
        models = [
            dict(
                role="inference",
                ssh="spark",
                model=model,
                architecture="arm64",
                directory=f"/opt/doglyad/{model}",
            )
            for model in ("medgemma-4b", "medgemma-15-4b", "medgemma-27b")
        ]
        targets = [*models, *self.targets[1:]]
        with patch.object(
            Path, "read_text", return_value=json.dumps({"targets": targets})
        ):
            self.assertEqual(update.inventory(Path("unused")), targets)
        calls = []

        def remote(target: dict, action: str, *args: object, **kwargs: object) -> dict:
            if action == "update":
                calls.append((target.get("directory"), kwargs["image"]))
            return {"image": "digest"}

        with patch.object(update, "remote", side_effect=remote):
            update.rollout(
                targets,
                "release",
                {
                    ("inference", "arm64"): "arm-image",
                    ("main", "amd64"): "x86-image",
                },
                "sha",
            )
        self.assertEqual(
            calls[:3], [(model["directory"], "arm-image") for model in models]
        )
        self.assertEqual(calls[3:], [(None, "x86-image"), (None, "x86-image")])

    def test_inventory_rejects_unsafe_or_duplicate_stack_directories(self) -> None:
        invalid = [
            dict(directory="/tmp/doglyad"),
            dict(directory="/opt/doglyad/../other"),
            dict(directory="/opt/doglyad/a;touch"),
            dict(architecture="x86"),
        ]
        for extra in invalid:
            targets = [dict(self.targets[0], **extra), *self.targets[1:]]
            with patch.object(
                Path, "read_text", return_value=json.dumps({"targets": targets})
            ):
                with self.assertRaises(ValueError):
                    update.inventory(Path("unused"))
        for directory in ("/opt/doglyad", "/opt/doglyad/child"):
            targets = [
                *self.targets,
                dict(self.targets[0], model="another", directory=directory),
            ]
            with patch.object(
                Path, "read_text", return_value=json.dumps({"targets": targets})
            ):
                with self.assertRaises(ValueError):
                    update.inventory(Path("unused"))

    def test_manifest_selects_arm64_and_rejects_missing_platform(self) -> None:
        manifest = [
            {
                "Descriptor": {
                    "platform": {"os": "linux", "architecture": arch},
                    "digest": "sha256:" + digit * 64,
                }
            }
            for arch, digit in (("amd64", "a"), ("arm64", "b"))
        ]
        with patch.object(update, "command", return_value=json.dumps(manifest)):
            self.assertEqual(
                update.platform_image("inference", "sha", "arm64"),
                update.REGISTRY + "inference@sha256:" + "b" * 64,
            )
        with patch.object(update, "command", return_value=json.dumps(manifest[:1])):
            with self.assertRaisesRegex(RuntimeError, "No linux/arm64"):
                update.platform_image("inference", "sha", "arm64")

    def test_failure_on_shared_host_rolls_back_only_attempted_model_directories(
        self,
    ) -> None:
        targets = [
            dict(
                role="inference",
                ssh="spark",
                model=name,
                architecture="arm64",
                directory=f"/opt/doglyad/{name}",
            )
            for name in ("first", "second", "third")
        ]
        calls = []

        def remote(target: dict, action: str, *args: object, **kwargs: object) -> dict:
            calls.append((target["directory"], action))
            if action == "update" and target["model"] == "second":
                raise RuntimeError("SSH lost after replacing second model backend")
            return {"image": "digest"}

        with patch.object(update, "remote", side_effect=remote):
            with self.assertRaises(RuntimeError):
                update.rollout(
                    targets, "release", {("inference", "arm64"): "image"}, "sha"
                )
        self.assertEqual(
            calls,
            [
                ("/opt/doglyad/first", "update"),
                ("/opt/doglyad/second", "update"),
                ("/opt/doglyad/second", "rollback"),
                ("/opt/doglyad/first", "rollback"),
            ],
        )

    def test_build_requires_both_publications_and_all_checks(self) -> None:
        for jobs, succeeds in (
            (
                [
                    {"name": name, "conclusion": "success"}
                    for name in (
                        "check (main)",
                        "check (inference)",
                        "check_billing",
                        "build (main, amd64)",
                        "build (inference, amd64)",
                        "build (inference, arm64)",
                        "publish (main)",
                        "publish (inference)",
                    )
                ],
                True,
            ),
            ([{"name": "publish (main)", "conclusion": "success"}], False),
            (
                [
                    {"name": "publish (main)", "conclusion": "success"},
                    {"name": "publish (inference)", "conclusion": "skipped"},
                ],
                False,
            ),
        ):
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
                    "conclusion": "success",
                    "headSha": "sha",
                    "jobs": jobs,
                },
            ]
            with (
                patch.object(update, "github", side_effect=responses),
                patch.object(update, "command"),
                patch.object(update.uuid, "uuid4") as unique,
            ):
                unique.return_value.hex = "unique"
                if succeeds:
                    self.assertEqual(update.build("master", 10), ("sha", "run-url"))
                else:
                    with self.assertRaises(RuntimeError):
                        update.build("master", 10)


if __name__ == "__main__":
    unittest.main()
