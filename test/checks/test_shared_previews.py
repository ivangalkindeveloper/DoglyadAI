from pathlib import Path
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import catalog
from artifacts import validate_suite


class SharedPreviewTests(unittest.TestCase):
    def generate(self, previews):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory).resolve()
            root = project / "test"
            root.mkdir()
            (root / "functional.json").write_text(json.dumps({
                "moduleOrder": ["Example"], "sharedPreviewOrder": ["ErrorBody"],
                "bootstrap": {"id": "bootstrap", "flow": "start.yaml", "screenshots": ["start"]},
                "cases": [],
            }))
            shared = project / catalog.SHARED_PREVIEWS.relative_to(catalog.ROOT)
            with (
                patch("catalog.TEST", root),
                patch("catalog.ROOT", project),
                patch("catalog.SHARED_PREVIEWS", shared),
                patch("catalog.inventory", return_value={"files": {}, "modules": [{"module": "Example"}]}),
                patch("catalog.extract", return_value=previews),
                patch("catalog.repository_adapters", return_value=""),
                patch("catalog.preview_documents", return_value={}),
            ):
                return catalog.generated()

    def previews(self):
        return [
            {"source": "ExamplePreview.swift", "title": "01 Screen", "body": "ExamplePreviewView()"},
            {"source": "ExamplePreview.swift", "title": "02 Card", "body": "ExampleCardView()"},
            {"source": str((catalog.SHARED_PREVIEWS / "ErrorBodyPreview.swift").relative_to(catalog.ROOT)),
             "title": "01 Failure", "body": "ErrorBodyView(description: \"Failure\")"},
        ]

    def test_modules_and_both_component_sources_are_registered(self):
        output = self.generate(self.previews())
        atlas = json.loads(output["catalog.json"])["atlas"]
        self.assertEqual([case["previewScope"] for case in atlas], ["module", "component", "component"])
        self.assertTrue(atlas[-1]["flow"].startswith("components/ErrorBody/atlas/"))
        self.assertTrue(all(case["flow"] in output for case in atlas))

    def test_component_previews_cannot_replace_full_module_coverage(self):
        previews = self.previews()[1:]
        previews[0]["title"] = "01 Card"
        with self.assertRaisesRegex(ValueError, "Modules without full-screen previews"):
            self.generate(previews)

    def test_shared_flows_must_be_registered_exactly(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            flow = root / "components/ErrorBody/atlas/atlas-failure.yaml"
            flow.parent.mkdir(parents=True)
            flow.write_text("appId: local\nname: atlas-failure\n---\n- takeScreenshot: failure\n")
            case = {"id": "atlas-failure", "kind": "render", "screenshots": ["failure"],
                    "flow": str(flow.relative_to(root))}
            with patch("artifacts.TEST", root), patch("artifacts.cases", return_value=[case]):
                self.assertEqual(validate_suite(), [case])
                flow.with_name("unregistered.yaml").write_text(flow.read_text())
                with self.assertRaisesRegex(ValueError, "Unregistered or missing flows"):
                    validate_suite()
