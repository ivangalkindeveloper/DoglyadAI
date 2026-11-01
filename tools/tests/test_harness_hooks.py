from __future__ import annotations

import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from harness.hooks import post_edit, security_check
from harness.checks.architecture import is_source


class HarnessHookTests(unittest.TestCase):
    def test_claude_edit_and_codex_patch_trigger_swift_formatting(self) -> None:
        for payload in (
            {
                "tool_input": {
                    "file_path": str(post_edit.ROOT / "ios/Doglyad/View.swift")
                }
            },
            {
                "cwd": str(post_edit.ROOT),
                "tool_input": {
                    "input": "*** Begin Patch\n*** Update File: ios/Doglyad/View.swift\n@@\n-old\n+new\n*** End Patch"
                },
            },
            {
                "cwd": str(post_edit.ROOT),
                "tool_input": "*** Begin Patch\n*** Add File: ios/Doglyad/New.swift\n+import SwiftUI\n*** End Patch",
            },
        ):
            with self.subTest(payload=payload):
                paths = post_edit.edited_paths(payload)
                self.assertEqual(len(paths), 1)
                self.assertTrue(is_source(paths[0]))

    def test_non_swift_and_protected_or_external_files_do_not_trigger(self) -> None:
        for path in (
            "backend/main/secrets/example.py",
            "ios/Config/Example.swift",
            "ios/Firebase/Example.swift",
            "ios/DoglyadNeuralModel/Resources/Example.swift",
            "ios/DerivedData/SourcePackages/Example.swift",
            "ios/Doglyad/Build/Generated.swift",
            "ios/Pods/Dependency.swift",
            "../Other.swift",
            "/tmp/Other.swift",
        ):
            paths = post_edit.edited_paths({"tool_input": {"file_path": path}})
            self.assertFalse(any(is_source(path) for path in paths))

    def test_format_hook_runs_only_ios_formatter_and_reports_failure(self) -> None:
        payload = json.dumps(
            {"tool_input": {"file_path": "ios/DoglyadUI/Component/DViewProtocol.swift"}}
        )
        with (
            patch("sys.stdin", io.StringIO(payload)),
            patch.object(
                post_edit.subprocess,
                "run",
                return_value=subprocess.CompletedProcess([], 1),
            ) as run,
            patch("sys.stderr", io.StringIO()),
        ):
            self.assertEqual(post_edit.main(), 2)
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0], ["make", "format-ios"])
        self.assertEqual(run.call_args.kwargs["cwd"], post_edit.ROOT)

    def test_formatter_finishes_before_architecture_and_violation_reaches_agent(
        self,
    ) -> None:
        payload = {
            "tool_input": {"file_path": "ios/DoglyadUI/Component/DViewProtocol.swift"}
        }
        with (
            patch("sys.stdin", io.StringIO(json.dumps(payload))),
            patch.object(
                post_edit.subprocess,
                "run",
                side_effect=[
                    subprocess.CompletedProcess([], 0),
                    subprocess.CompletedProcess(
                        [], 1, stdout="source.swift:2: swift.view-method\n", stderr=""
                    ),
                ],
            ) as run,
            patch("sys.stderr", io.StringIO()) as stderr,
        ):
            self.assertEqual(post_edit.main(), 2)
        self.assertEqual(run.call_args_list[0].args[0], ["make", "format-ios"])
        self.assertIn("architecture.py", run.call_args_list[1].args[0][1])
        self.assertIn("source.swift:2", stderr.getvalue())

    def test_backend_hook_checks_without_formatter(self) -> None:
        payload = {"tool_input": {"file_path": "backend/main/app/main.py"}}
        with (
            patch("sys.stdin", io.StringIO(json.dumps(payload))),
            patch.object(
                post_edit.subprocess,
                "run",
                return_value=subprocess.CompletedProcess([], 0, "", ""),
            ) as run,
        ):
            self.assertEqual(post_edit.main(), 0)
        self.assertEqual(run.call_count, 1)
        self.assertIn("architecture.py", run.call_args.args[0][1])

    def test_deleted_and_unrelated_files_do_not_run_any_check(self) -> None:
        for value in ("README.md", "ios/Doglyad/DoesNotExist.swift"):
            with (
                patch(
                    "sys.stdin",
                    io.StringIO(json.dumps({"tool_input": {"file_path": value}})),
                ),
                patch.object(post_edit.subprocess, "run") as run,
            ):
                self.assertEqual(post_edit.main(), 0)
                run.assert_not_called()

    def test_move_targets_and_paths_relative_to_hook_cwd(self) -> None:
        payload = {
            "cwd": str(post_edit.ROOT / "ios"),
            "tool_input": {
                "patch": "*** Update File: Doglyad/Old.swift\n*** Move to: Doglyad/New.swift\n"
            },
        }
        self.assertEqual(
            post_edit.edited_paths(payload),
            [
                post_edit.ROOT / "ios/Doglyad/New.swift",
                post_edit.ROOT / "ios/Doglyad/Old.swift",
            ],
        )

    def test_real_backend_hook_reports_violation(self) -> None:
        # Real process and stdin contract, with no imports of the application or external services.
        folder = post_edit.ROOT / "backend/main/app/model"
        with tempfile.NamedTemporaryFile(suffix=".py", dir=folder) as file:
            file.write(b"from app.route.ultrasound import generate_report\n")
            file.flush()
            result = subprocess.run(
                ["python3", str(post_edit.ROOT / "harness/hooks/post_edit.py")],
                input=json.dumps(
                    {"tool_name": "Write", "tool_input": {"file_path": file.name}}
                ),
                capture_output=True,
                text=True,
                check=False,
            )
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("python.layer-import", result.stderr)

    def test_shared_security_hook_blocks_explicit_secret_for_both_clients(self) -> None:
        for tool, key in (("Bash", "command"), ("exec_command", "cmd")):
            payload = {
                "tool_name": tool,
                "tool_input": {
                    key: 'git add "backend/main/secrets/credentials with spaces.json"'
                },
            }
            with (
                patch("sys.stdin", io.StringIO(json.dumps(payload))),
                patch.object(security_check, "repo_root", return_value=str(Path.cwd())),
                patch.object(security_check, "exists_in_worktree", return_value=True),
                patch("sys.stderr", io.StringIO()),
            ):
                self.assertEqual(security_check.main(), 2)

    def test_service_secret_directories_are_protected(self) -> None:
        for value in (
            "backend/main/secrets/inference_endpoints.json",
            "backend/inference/secrets/firebase.json",
            "deploy/secrets/inventory.json",
            "ios/Firebase/GoogleService-Info.plist",
        ):
            self.assertIsNotNone(security_check.matches_deny(value))
        self.assertIsNone(security_check.matches_deny("harness/mcp/servers.json"))

    def test_unrelated_commands_and_deleted_secrets_are_allowed(self) -> None:
        for command in (
            "git status --short",
            "git rm --cached .codex/settings.json",
            "git add backend/main/secrets/deleted.json",
        ):
            payload = {"tool_name": "Bash", "tool_input": {"command": command}}
            with (
                patch("sys.stdin", io.StringIO(json.dumps(payload))),
                patch.object(security_check, "repo_root", return_value=str(Path.cwd())),
                patch.object(security_check, "exists_in_worktree", return_value=False),
            ):
                self.assertEqual(security_check.main(), 0)


if __name__ == "__main__":
    unittest.main()
