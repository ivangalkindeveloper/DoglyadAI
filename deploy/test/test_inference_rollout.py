from __future__ import annotations

import copy
import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import update_remote as remote


class InferenceRolloutTests(unittest.TestCase):
    def setUp(self) -> None:
        self.local_weights = {}
        self.target = {
            "role": "inference",
            "architecture": "arm64",
            "models": {"model/a": "engine_a", "model/b": "engine_b"},
            "profile_fingerprint": "a" * 64,
        }
        self.backend = {
            "Id": "api",
            "Image": "image",
            "RestartCount": 0,
            "State": {"Running": True},
            "HostConfig": {
                "PortBindings": {
                    "8000/tcp": [{"HostIp": "100.64.0.1", "HostPort": "8100"}]
                }
            },
        }
        self.engines = {
            name: {
                "Id": name,
                "Image": "vllm-image",
                "RestartCount": 0,
                "State": {"Running": True, "Health": {"Status": "healthy"}},
                "HostConfig": {"PortBindings": {}},
                "Config": {"Cmd": [name]},
            }
            for name in self.target["models"].values()
        }

    def check(self) -> dict:
        def run(*args: str, **kwargs: object) -> str:
            if args == ("uname", "-m"):
                return "aarch64"
            if args[:2] == ("tailscale", "ip"):
                return "100.64.0.1"
            if remote.PROFILE_CHECK in args:
                return json.dumps(
                    {
                        name: {
                            "command": [name],
                            "image": "vllm-image",
                            "weightsDirectory": self.local_weights.get(name),
                        }
                        for name in self.engines
                    }
                )
            if args[:3] == ("docker", "image", "inspect"):
                return "vllm-image"
            if remote.ENGINE_CHECK in args:
                self.assertEqual(
                    json.loads(args[-1]),
                    {
                        "model/a": "http://engine_a:8000",
                        "model/b": "http://engine_b:8000",
                    },
                )
            return ""

        with (
            patch.object(
                remote, "values", return_value={"INFERENCE_BACKEND_BIND": "100.64.0.1"}
            ),
            patch.object(remote, "compose"),
            patch.object(
                remote,
                "container",
                side_effect=lambda name: self.backend
                if name == "backend_inference"
                else self.engines[name],
            ),
            patch.object(remote, "run", side_effect=run),
            patch.object(remote, "http") as http,
        ):
            result = remote.check(self.target)
            http.assert_called_once()
            return result

    def test_preflight_records_every_engine_for_preservation(self) -> None:
        result = self.check()
        self.assertEqual(
            result["companion"],
            {
                name: {"id": name, "image": "vllm-image", "restarts": 0}
                for name in self.engines
            },
        )

    def test_unhealthy_or_public_engine_blocks_rollout(self) -> None:
        for mutation in [
            lambda e: e["State"]["Health"].update(Status="unhealthy"),
            lambda e: e["HostConfig"].update(PortBindings={"8000/tcp": [{}]}),
            lambda e: e["HostConfig"].update(NetworkMode="host"),
        ]:
            with self.subTest(mutation=mutation):
                original = copy.deepcopy(self.engines)
                mutation(self.engines["engine_b"])
                with self.assertRaises(RuntimeError):
                    self.check()
                self.engines = original

    def test_public_backend_binding_blocks_rollout(self) -> None:
        self.backend["HostConfig"]["PortBindings"]["8000/tcp"][0]["HostIp"] = "0.0.0.0"
        with self.assertRaisesRegex(RuntimeError, "binding"):
            self.check()

    def test_running_engine_drift_blocks_backend_rollout(self) -> None:
        self.engines["engine_b"]["Config"]["Cmd"] = ["another-model"]
        with self.assertRaisesRegex(RuntimeError, "parameters/image"):
            self.check()

    def test_restart_of_any_engine_fails_readiness(self) -> None:
        state = self.check()
        changed = copy.deepcopy(state)
        changed["companion"]["engine_b"]["restarts"] = 1
        with (
            patch.object(remote, "check", return_value=changed),
            patch.object(remote.time, "sleep"),
            self.assertRaises(RuntimeError),
        ):
            remote.wait_ready(self.target, state["image"], state["companion"])

    def test_local_checkpoint_requires_the_expected_read_only_mount(self) -> None:
        self.local_weights["engine_a"] = "/models/approved"
        valid = {
            "Type": "bind",
            "Source": "/models/approved",
            "Destination": "/model",
            "RW": False,
        }
        self.engines["engine_a"]["Mounts"] = [valid]
        self.check()
        for mounts in (
            [],
            [dict(valid, Source="/models/other")],
            [dict(valid, RW=True)],
        ):
            self.engines["engine_a"]["Mounts"] = mounts
            with self.assertRaisesRegex(RuntimeError, "weights mount"):
                self.check()

    def test_old_single_engine_snapshot_remains_recoverable(self) -> None:
        current = {"vllm": {"id": "original", "image": "image", "restarts": 0}}
        self.assertTrue(remote._companions_match(current, "original"))
        self.assertFalse(remote._companions_match(current, "replacement"))
        self.assertFalse(
            remote._companions_match(
                {**current, "another": current["vllm"]}, "original"
            )
        )

    def test_engine_probe_rejects_foreign_routes_and_wrong_served_model(self) -> None:
        # Execute the actual remote probe, supplying lightweight app/HTTP modules.
        program = """
import contextlib, io, json, sys, types
from unittest.mock import patch
routes = json.loads(sys.argv[2])
model = sys.argv[3]
variables = types.ModuleType('app.core.variables')
variables.Variables = lambda: types.SimpleNamespace(model_endpoints=routes)
sys.modules['app'] = types.ModuleType('app')
sys.modules['app.core'] = types.ModuleType('app.core')
sys.modules['app.core.variables'] = variables
class Response(io.StringIO):
    status = 200
class Opener:
    def open(self, url, timeout):
        return Response(json.dumps({'data':[{'id':model}]}))
with patch('urllib.request.build_opener', return_value=Opener()):
    exec(sys.argv[4])
"""
        expected = {"model/a": "http://engine_a:8000"}
        for actual, served, is_ok in [
            (expected, "model/a", True),
            (expected, "model/b", False),
            ({"model/b": "http://another-host:8000"}, "model/b", False),
        ]:
            with self.subTest(actual=actual, served=served):
                result = subprocess.run(
                    [
                        sys.executable,
                        "-c",
                        program,
                        json.dumps(expected),
                        json.dumps(actual),
                        served,
                        remote.ENGINE_CHECK,
                    ],
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(result.returncode == 0, is_ok)


if __name__ == "__main__":
    unittest.main()
