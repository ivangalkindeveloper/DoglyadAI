from __future__ import annotations

import copy
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "inference"))

import render
import start
from compose_document import compose_document
from host_profile import HostProfile

DIRECTORY = Path(__file__).resolve().parents[1] / "inference"


class InferenceProfileTests(unittest.TestCase):
    def setUp(self) -> None:
        self.profile = HostProfile.load(DIRECTORY / "profiles/dgx-spark.json")
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.output = Path(self.temporary.name) / "host"

    def render(self, *args: str) -> int:
        with patch.object(
            sys,
            "argv",
            [
                "render",
                "--profile",
                str(DIRECTORY / "profiles/dgx-spark.json"),
                "--output",
                str(self.output),
                *args,
            ],
        ):
            return render.main()

    def test_each_profile_exposes_only_its_own_models_and_private_engines(self) -> None:
        for name, count in [("dgx-spark", 3), ("medgemma-4b-amd64", 1)]:
            profile = HostProfile.load(DIRECTORY / f"profiles/{name}.json")
            document = compose_document(profile)
            backend = document["services"]["backend_inference"]
            routes = json.loads(backend["environment"]["VLLM_ENDPOINTS"])
            self.assertEqual(len(routes), count)
            self.assertEqual(routes, profile.endpoints)
            self.assertEqual(backend["environment"]["SERVED_MODEL_ID"], "")
            self.assertNotIn("env_file", backend)
            for model, service in profile.models.items():
                engine = document["services"][service]
                self.assertNotIn("ports", engine)
                self.assertNotIn("network_mode", engine)
                self.assertEqual(engine["command"][0], model)
                self.assertEqual(engine["platform"], f"linux/{profile.architecture}")
                self.assertIn("--no-enable-log-requests", engine["command"])
            self.assertNotIn("HF_TOKEN", json.dumps(document))

    def test_rejects_invalid_profiles_before_any_files_are_written(self) -> None:
        changes = [
            lambda p: p["models"].append(copy.deepcopy(p["models"][0])),
            lambda p: p["models"][0].update(service="backend_inference"),
            lambda p: p["models"][0].update(service="bad;cmd"),
            lambda p: p["models"][0].update(modelId="${HF_TOKEN}"),
            lambda p: p["models"][0].update(gpuMemoryUtilization=1.1),
            lambda p: p["models"][0].update(maxModelLen=True),
            lambda p: p["models"][0].update(tensorParallelSize=2),
            lambda p: p["models"][0].update(gpuDeviceIds=["0", "0"]),
            lambda p: p["models"][0].update(isEager="true"),
            lambda p: p["models"][0].update(unknownSetting=1),
            lambda p: p.update(vllmImage="vllm/vllm-openai:latest"),
            lambda p: p.update(models=[]),
        ]
        for change in changes:
            with self.subTest(change=change):
                data = copy.deepcopy(self.profile.data)
                change(data)
                with self.assertRaises(ValueError):
                    HostProfile(data, self.profile.server_config)

    def test_duplicate_json_keys_are_rejected(self) -> None:
        path = Path(self.temporary.name) / "duplicate.json"
        path.write_text('{"serverConfig":"a", "serverConfig":"b"}')
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            HostProfile.load(path)

    def test_ngram_configuration_is_serialized_as_one_cli_argument(self) -> None:
        document = compose_document(self.profile)
        for service in self.profile.models.values():
            command = document["services"][service]["command"]
            self.assertEqual(command.count("--speculative-config"), 1)
            config = json.loads(command[command.index("--speculative-config") + 1])
            self.assertEqual(
                config,
                {
                    "method": "ngram",
                    "num_speculative_tokens": 8,
                    "prompt_lookup_min": 2,
                    "prompt_lookup_max": 5,
                },
            )
        other = HostProfile.load(DIRECTORY / "profiles/medgemma-4b-amd64.json")
        for service in other.models.values():
            self.assertNotIn(
                "--speculative-config",
                compose_document(other)["services"][service]["command"],
            )

    def test_invalid_ngram_configuration_is_rejected(self) -> None:
        valid = {
            "method": "ngram",
            "numSpeculativeTokens": 8,
            "promptLookupMin": 2,
            "promptLookupMax": 5,
        }
        invalid = [
            None,
            [],
            {},
            dict(valid, method="eagle"),
            dict(valid, numSpeculativeTokens=True),
            dict(valid, numSpeculativeTokens=0),
            dict(valid, promptLookupMin=0),
            dict(valid, promptLookupMax="5"),
            dict(valid, promptLookupMax=1),
            dict(valid, unknown=1),
        ]
        for config in invalid:
            with self.subTest(config=config):
                data = copy.deepcopy(self.profile.data)
                data["models"][0]["speculativeConfig"] = config
                with self.assertRaises(ValueError):
                    HostProfile(data, self.profile.server_config)

    @unittest.skipUnless(shutil.which("docker"), "Docker Compose CLI is not installed")
    def test_docker_compose_accepts_generated_arm64_and_amd64_stacks(self) -> None:
        for name in ["dgx-spark", "medgemma-4b-amd64"]:
            output = Path(self.temporary.name) / name
            with patch.object(
                sys,
                "argv",
                [
                    "render",
                    "--profile",
                    str(DIRECTORY / f"profiles/{name}.json"),
                    "--output",
                    str(output),
                ],
            ):
                render.main()
            (output / "secrets").mkdir()
            (output / "secrets/.env").write_text("HF_TOKEN=fixture\n")
            (output / "secrets/firebase_credentials.json").write_text("{}")
            (output / ".env").write_text(
                "INFERENCE_BACKEND_IMAGE=sha256:"
                + "a" * 64
                + "\nINFERENCE_BACKEND_BIND=100.64.0.10\n"
            )
            result = subprocess.run(
                [
                    "docker",
                    "compose",
                    "--env-file",
                    str(output / ".env"),
                    "-f",
                    str(output / "docker-compose.yml"),
                    "config",
                    "--format",
                    "json",
                ],
                capture_output=True,
                text=True,
                check=True,
            )
            resolved = json.loads(result.stdout)
            profile = HostProfile.load(output / "profile.json")
            backend = resolved["services"]["backend_inference"]
            self.assertEqual(
                json.loads(backend["environment"]["VLLM_ENDPOINTS"]), profile.endpoints
            )
            self.assertEqual(backend["ports"][0]["host_ip"], "100.64.0.10")
            for service in profile.models.values():
                self.assertFalse(resolved["services"][service].get("ports"))

    def test_generation_is_portable_and_preserves_operational_files(self) -> None:
        self.output.mkdir()
        (self.output / ".env").write_text("existing machine settings")
        (self.output / "secrets").mkdir()
        (self.output / "secrets/.env").write_text("fixture credentials")
        with patch.object(subprocess, "run") as run:
            self.render()
            run.assert_not_called()
        bundled = HostProfile.load(self.output / "profile.json")
        self.assertEqual(bundled.fingerprint, self.profile.fingerprint)
        self.assertEqual(
            json.loads((self.output / "docker-compose.yml").read_text()),
            compose_document(bundled),
        )
        self.assertEqual(
            (self.output / ".env").read_text(), "existing machine settings"
        )
        self.assertEqual(
            (self.output / "secrets/.env").read_text(), "fixture credentials"
        )
        self.assertEqual(self.render("--check"), 0)
        (self.output / "docker-compose.yml").write_text("{}")
        with self.assertRaisesRegex(ValueError, "differs"):
            self.render("--check")

    def test_output_symlink_cannot_overwrite_another_file(self) -> None:
        self.output.mkdir()
        victim = Path(self.temporary.name) / "existing"
        victim.write_text("preserve")
        (self.output / "docker-compose.yml").symlink_to(victim)
        with self.assertRaisesRegex(ValueError, "symbolic"):
            self.render()
        self.assertEqual(victim.read_text(), "preserve")

    def start(
        self, *, is_restart: bool = False, failed_engine: str | None = None
    ) -> list[list[str]]:
        self.render()
        calls = []
        resolved = {
            "name": self.profile.data["projectName"],
            "services": {
                "backend_inference": {
                    "image": "sha256:" + "a" * 64,
                    "ports": [{"host_ip": "100.64.0.10"}],
                }
            },
        }

        def execute(
            command: list[str], **kwargs: object
        ) -> subprocess.CompletedProcess:
            calls.append(command)
            if "config" in command:
                return subprocess.CompletedProcess(command, 0, json.dumps(resolved))
            if command[:2] == ["tailscale", "ip"]:
                return subprocess.CompletedProcess(command, 0, "100.64.0.10\n")
            if failed_engine and command[-1] == failed_engine:
                raise subprocess.CalledProcessError(1, command)
            return subprocess.CompletedProcess(command, 0, "")

        with (
            patch.object(start, "__file__", str(self.output / "start.py")),
            patch.object(
                sys, "argv", ["start", *(["--restart"] if is_restart else [])]
            ),
            patch.object(start.platform, "machine", return_value="aarch64"),
            patch.object(start.subprocess, "run", side_effect=execute),
        ):
            if failed_engine:
                with self.assertRaises(subprocess.CalledProcessError):
                    start.main()
            else:
                self.assertEqual(start.main(), 0)
        return calls

    def test_startup_waits_for_each_engine_before_api(self) -> None:
        calls = self.start(is_restart=True)
        starts = [call for call in calls if "up" in call]
        self.assertEqual(
            [call[-1] for call in starts],
            [*self.profile.models.values(), "backend_inference"],
        )
        self.assertTrue(all("--wait" in call for call in starts[:-1]))
        stop = next(call for call in calls if "stop" in call)
        self.assertEqual(
            stop[-4:],
            ["backend_inference", *reversed(list(self.profile.models.values()))],
        )

    def test_failed_engine_stops_sequence_before_next_engine_and_api(self) -> None:
        calls = self.start(failed_engine="vllm_medgemma_4b")
        self.assertEqual(
            [call[-1] for call in calls if "up" in call],
            ["vllm_medgemma_27b", "vllm_medgemma_4b"],
        )

    def test_startup_guards_fail_before_any_container_mutation(self) -> None:
        self.render()
        for condition in ["architecture", "binding", "image", "project", "retired"]:
            with self.subTest(condition=condition):
                document = {
                    "name": "another-project"
                    if condition == "project"
                    else self.profile.data["projectName"],
                    "services": {
                        "backend_inference": {
                            "image": "image:latest"
                            if condition == "image"
                            else "sha256:" + "a" * 64,
                            "ports": [
                                {
                                    "host_ip": "0.0.0.0"
                                    if condition == "binding"
                                    else "100.64.0.10"
                                }
                            ],
                        }
                    },
                }
                calls = []

                def run(
                    command: list[str], **kwargs: object
                ) -> subprocess.CompletedProcess:
                    calls.append(command)
                    value = "retired_engine\n" if condition == "retired" else ""
                    if "config" in command:
                        value = json.dumps(document)
                    elif command[0] == "tailscale":
                        value = "100.64.0.10\n"
                    return subprocess.CompletedProcess(command, 0, value)

                with (
                    patch.object(start, "__file__", str(self.output / "start.py")),
                    patch.object(sys, "argv", ["start", "--restart"]),
                    patch.object(
                        start.platform,
                        "machine",
                        return_value="x86_64"
                        if condition == "architecture"
                        else "aarch64",
                    ),
                    patch.object(start.subprocess, "run", side_effect=run),
                    self.assertRaises(ValueError),
                ):
                    start.main()
                self.assertFalse(any("up" in call or "stop" in call for call in calls))


if __name__ == "__main__":
    unittest.main()
