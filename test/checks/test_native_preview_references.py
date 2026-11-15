from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from native_checks import validate_preview_references


class NativePreviewReferencesTests(unittest.TestCase):
    def test_stale_native_preview_is_rejected_before_running_xcode(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "Gestures.swift"
            source.write_text('launch(preview: "atlas-photoview-deadbeef")')
            with self.assertRaisesRegex(
                ValueError, "unknown Preview: atlas-photoview-deadbeef"
            ):
                validate_preview_references(
                    [{"id": "atlas-photoview-current"}], source.parent
                )

    def test_registered_preview_reference_passes(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "Gestures.swift"
            source.write_text('launch(preview: "atlas-photoview-current")')
            validate_preview_references(
                [{"id": "atlas-photoview-current"}], source.parent
            )
