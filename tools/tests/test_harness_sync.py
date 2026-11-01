from __future__ import annotations

import json
from pathlib import Path
import shlex
import shutil
import stat
import tempfile
import tomllib
import unittest

from tools.sync_harness import STATE, fingerprint, render, synchronize

SOURCE = Path(__file__).resolve().parents[2]


class HarnessSyncTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="doglyad harness '")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        shutil.copytree(SOURCE / "harness", self.root / "harness")
        (self.root / "AGENTS.md").write_text("Shared instructions\n")

    def test_fresh_checkout_native_configs_and_idempotence(self) -> None:
        synchronize(self.root)
        codex = tomllib.loads((self.root / ".codex/config.toml").read_text())
        claude = json.loads((self.root / ".mcp.json").read_text())
        for key in ("command", "args", "env"):
            self.assertEqual(
                codex["mcp_servers"]["MobileBuildMCP"][key],
                claude["mcpServers"]["MobileBuildMCP"][key],
            )
        for directory in (".agents/skills", ".claude/skills"):
            self.assertEqual(
                (self.root / directory / "sync-harness/SKILL.md").read_bytes(),
                (self.root / "harness/skills/sync-harness/SKILL.md").read_bytes(),
            )
        hooks = json.loads((self.root / ".codex/hooks.json").read_text())
        command = hooks["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
        self.assertEqual(
            shlex.split(command),
            ["python3", str(self.root / "harness/hooks/security_check.py")],
        )
        for config_path in (".codex/hooks.json", ".claude/settings.json"):
            config = json.loads((self.root / config_path).read_text())
            post = config["hooks"]["PostToolUse"][0]["hooks"]
            self.assertEqual(len(post), 1)
            self.assertEqual(
                shlex.split(post[0]["command"]),
                ["python3", str(self.root / "harness/hooks/post_edit.py")],
            )
        before = {
            path: path.stat().st_mtime_ns
            for path in self.root.rglob("*")
            if path.is_file()
        }
        self.assertEqual(synchronize(self.root), [])
        self.assertEqual(synchronize(self.root, check=True), [])
        self.assertEqual(before, {path: path.stat().st_mtime_ns for path in before})

    def test_source_update_and_pruning_preserve_personal_files(self) -> None:
        synchronize(self.root)
        personal = self.root / ".claude/settings.local.json"
        personal.write_text('{"personal": true}\n')
        unmanaged = self.root / ".agents/skills/personal/SKILL.md"
        unmanaged.parent.mkdir()
        unmanaged.write_text("Personal skill\n")
        source = self.root / "harness/skills/build-verify/SKILL.md"
        source.write_text(source.read_text() + "\nAdditional instruction.\n")
        shutil.rmtree(self.root / "harness/skills/init-ios-local")
        with self.assertRaisesRegex(ValueError, "out of sync"):
            synchronize(self.root, check=True)
        synchronize(self.root)
        self.assertFalse(
            (self.root / ".agents/skills/init-ios-local/SKILL.md").exists()
        )
        self.assertFalse(
            (self.root / ".claude/skills/init-ios-local/SKILL.md").exists()
        )
        self.assertEqual(personal.read_text(), '{"personal": true}\n')
        self.assertEqual(unmanaged.read_text(), "Personal skill\n")

    def test_conflict_prevents_all_writes_including_unrelated_updates(self) -> None:
        synchronize(self.root)
        edited = self.root / ".agents/skills/build-verify/SKILL.md"
        edited.write_text("Manual edit\n")
        source = self.root / "harness/skills/github/SKILL.md"
        source.write_text(source.read_text() + "\nNew source\n")
        other = self.root / ".claude/skills/github/SKILL.md"
        before = other.read_bytes()
        manifest = (self.root / STATE).read_bytes()
        with self.assertRaisesRegex(ValueError, "Manual or unmanaged"):
            synchronize(self.root)
        self.assertEqual(edited.read_text(), "Manual edit\n")
        self.assertEqual(other.read_bytes(), before)
        self.assertEqual((self.root / STATE).read_bytes(), manifest)

    def test_initial_unmanaged_config_is_never_overwritten(self) -> None:
        path = self.root / ".codex/config.toml"
        path.parent.mkdir()
        path.write_text('model = "personal"\n')
        with self.assertRaisesRegex(ValueError, "Manual or unmanaged"):
            synchronize(self.root)
        self.assertEqual(path.read_text(), 'model = "personal"\n')
        self.assertFalse((self.root / ".agents").exists())

    def test_dry_run_does_not_create_agent_outputs(self) -> None:
        self.assertIn(STATE, synchronize(self.root, dry_run=True))
        self.assertFalse((self.root / ".codex").exists())
        self.assertFalse((self.root / ".claude").exists())

    def test_symlink_parent_and_manifest_path_escape_are_rejected(self) -> None:
        outside = self.root / "outside"
        outside.mkdir()
        (self.root / ".agents").symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symlink"):
            synchronize(self.root)
        self.assertEqual(list(outside.iterdir()), [])
        (self.root / ".agents").unlink()
        synchronize(self.root)
        manifest = self.root / STATE
        data = json.loads(manifest.read_text())
        data["files"]["../outside.txt"] = "unused"
        manifest.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "Invalid generated path"):
            synchronize(self.root)

    def test_edited_obsolete_skill_is_not_removed(self) -> None:
        synchronize(self.root)
        edited = self.root / ".claude/skills/init-ios-local/SKILL.md"
        edited.write_text("Keep my edit\n")
        shutil.rmtree(self.root / "harness/skills/init-ios-local")
        with self.assertRaisesRegex(ValueError, "Manual or unmanaged"):
            synchronize(self.root)
        self.assertTrue((self.root / ".agents/skills/init-ios-local/SKILL.md").exists())
        self.assertEqual(edited.read_text(), "Keep my edit\n")

    def test_executable_resource_mode_is_preserved(self) -> None:
        script = self.root / "harness/skills/sync-harness/scripts/check.sh"
        script.parent.mkdir()
        script.write_text("#!/bin/sh\nexit 0\n")
        script.chmod(0o755)
        synchronize(self.root)
        copied = self.root / ".agents/skills/sync-harness/scripts/check.sh"
        self.assertEqual(stat.S_IMODE(copied.stat().st_mode), 0o755)

    def test_migration_uses_recorded_hashes_and_retains_local_settings(self) -> None:
        legacy = self.root / ".codex/skills/old/SKILL.md"
        legacy.parent.mkdir(parents=True)
        legacy.write_text("Legacy skill\n")
        legacy.chmod(0o644)
        personal = self.root / ".claude/settings.local.json"
        personal.parent.mkdir()
        personal.write_text("{}\n")
        (self.root / STATE).write_text(
            json.dumps(
                {
                    "version": 1,
                    "files": {
                        ".codex/skills/old/SKILL.md": fingerprint(
                            legacy.read_bytes(), 0o644
                        ),
                    },
                }
            )
        )
        synchronize(self.root)
        self.assertFalse(legacy.exists())
        self.assertEqual(personal.read_text(), "{}\n")
        self.assertEqual(synchronize(self.root, check=True), [])

    def test_all_rendered_paths_are_relative_to_the_checkout(self) -> None:
        outputs = render(self.root)
        self.assertTrue(all(not Path(path).is_absolute() for path in outputs))
        self.assertNotIn(".claude/settings.local.json", outputs)
        self.assertNotIn(".codex/settings.json", outputs)


if __name__ == "__main__":
    unittest.main()
