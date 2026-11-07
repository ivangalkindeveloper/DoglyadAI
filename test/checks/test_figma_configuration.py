from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from configure_figma import KEY_MARKER, SHA256_MARKER, bridge_key, configure


class FigmaConfigurationTests(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.source = self.root / "figma"
        self.source.mkdir()
        (self.source / "manifest.json").write_text(
            json.dumps(
                {"name": "Doglyad AI Regression", "main": "code.js", "ui": "ui.html"}
            )
        )
        (self.source / "code.js").write_text("figma.showUI(__html__);")
        (self.source / "ui.html").write_text(
            "<script>" + SHA256_MARKER + "\nconst key = " + KEY_MARKER + ";</script>"
        )
        vendor = self.source / "vendor/js-sha256"
        vendor.mkdir(parents=True)
        (vendor / "sha256.js").write_text("function sha256() { return 'test'; }")
        (vendor / "LICENSE.txt").write_text("MIT license notice")

    def test_importable_manifest_contains_resolvable_javascript_and_ui(self) -> None:
        path = configure("123", self.root)
        self.assertEqual(path.name, "manifest.json")
        manifest = json.loads(path.read_text())
        self.assertEqual(manifest["id"], "123")
        self.assertEqual(
            (path.parent / manifest["main"]).read_bytes(),
            (self.source / "code.js").read_bytes(),
        )
        ui = (path.parent / manifest["ui"]).read_text()
        self.assertIn(json.dumps(bridge_key(self.root)), ui)
        self.assertNotIn(KEY_MARKER, ui)
        self.assertIn("function sha256()", ui)
        self.assertIn("MIT license notice", ui)
        self.assertNotIn(SHA256_MARKER, ui)

    def test_authentication_survives_refresh_and_stays_in_ignored_local_files(
        self,
    ) -> None:
        path = configure("123", self.root)
        original_key = bridge_key(self.root)
        configure(root=self.root)
        self.assertEqual(bridge_key(self.root), original_key)
        key_file = self.root / "secrets/figma-bridge-key"
        self.assertEqual(key_file.stat().st_mode & 0o777, 0o600)
        self.assertEqual((path.parent / "ui.html").stat().st_mode & 0o777, 0o600)
        for source in self.source.rglob("*"):
            if source.is_file():
                self.assertNotIn(original_key, source.read_text())

    def test_corrupt_key_does_not_silently_break_open_plugin_authentication(
        self,
    ) -> None:
        configure("123", self.root)
        (self.root / "secrets/figma-bridge-key").write_text("broken")
        with self.assertRaisesRegex(ValueError, "Invalid.*bridge-key"):
            configure(root=self.root)

    def test_previous_local_manifest_is_migrated_without_losing_its_id(self) -> None:
        (self.source / "manifest.local.json").write_text('{"id":"456"}')
        path = configure(root=self.root)
        self.assertEqual(path.name, "manifest.json")
        self.assertEqual(json.loads(path.read_text())["id"], "456")

    def test_refresh_updates_code_and_preserves_configured_id(self) -> None:
        path = configure("789", self.root)
        (self.source / "code.js").write_text("figma.showUI(__html__, { width: 420 });")
        self.assertEqual(configure(root=self.root), path)
        self.assertEqual(json.loads(path.read_text())["id"], "789")
        self.assertEqual(
            (path.parent / "code.js").read_bytes(),
            (self.source / "code.js").read_bytes(),
        )

    def test_missing_id_does_not_create_a_broken_plugin(self) -> None:
        with self.assertRaises(ValueError):
            configure(root=self.root)
        self.assertFalse((self.root / "cache/figma-plugin/manifest.json").exists())

    def test_missing_checksum_library_prevents_incomplete_plugin_creation(self) -> None:
        (self.source / "vendor/js-sha256/sha256.js").unlink()
        with self.assertRaises(FileNotFoundError):
            configure("123", self.root)
        self.assertFalse((self.root / "cache/figma-plugin/manifest.json").exists())
