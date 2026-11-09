from pathlib import Path
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import catalog
from artifacts import validate_suite


class ModulePreviewScopeTests(unittest.TestCase):
    def generate(self, previews):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory).resolve()
            root = project / "test"
            root.mkdir()
            (root / "functional.json").write_text(
                json.dumps(
                    {
                        "moduleOrder": ["Example"],
                        "bootstrap": {
                            "id": "bootstrap",
                            "flow": "start.yaml",
                            "screenshots": ["start"],
                        },
                        "cases": [],
                    }
                )
            )
            shared = project / catalog.SHARED_PREVIEWS.relative_to(catalog.ROOT)
            with (
                patch("catalog.TEST", root),
                patch("catalog.ROOT", project),
                patch("catalog.SHARED_PREVIEWS", shared),
                patch(
                    "catalog.inventory",
                    return_value={"files": {}, "modules": [{"module": "Example"}]},
                ),
                patch("catalog.extract", return_value=previews),
                patch("catalog.repository_adapters", return_value=""),
                patch("catalog.preview_documents", return_value={}),
            ):
                return catalog.generated()

    def previews(self):
        return [
            {
                "source": "ExamplePreview.swift",
                "title": "01 ExampleDefaultState Content",
                "body": "ExamplePreviewView()",
            },
            {
                "source": "ExamplePreview.swift",
                "title": "02 Card",
                "body": "ExampleCardView()",
            },
            {
                "source": str(
                    (catalog.SHARED_PREVIEWS / "ErrorBodyPreview.swift").relative_to(
                        catalog.ROOT
                    )
                ),
                "title": "01 Failure",
                "body": 'ErrorBodyView(description: "Failure")',
            },
        ]

    def test_only_full_modules_are_registered_and_generated(self):
        output = self.generate(self.previews())
        atlas = json.loads(output["catalog.json"])["atlas"]
        self.assertEqual([case["previewScope"] for case in atlas], ["module"])
        self.assertEqual(len(atlas), 1)
        self.assertTrue(atlas[0]["flow"].startswith("modules/Example/atlas/"))
        self.assertFalse(any(key.startswith("components/") for key in output))
        self.assertNotIn(
            "ExampleCardView()",
            output["../ios/Doglyad/Regression/RegressionScreens.swift"],
        )

    def test_component_previews_cannot_replace_full_module_coverage(self):
        previews = self.previews()[1:]
        previews[0]["title"] = "01 Card"
        with self.assertRaisesRegex(ValueError, "Modules without full-screen previews"):
            self.generate(previews)

    def test_component_case_is_rejected_even_if_its_flow_exists(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            flow = root / "modules/Example/atlas/component.yaml"
            flow.parent.mkdir(parents=True)
            flow.write_text(
                "appId: local\nname: component\n---\n- takeScreenshot: component\n"
            )
            case = {
                "id": "component",
                "kind": "render",
                "previewScope": "component",
                "flow": str(flow.relative_to(root)),
                "screenshots": ["component"],
            }
            with (
                patch("artifacts.TEST", root),
                patch("artifacts.cases", return_value=[case]),
            ):
                with self.assertRaisesRegex(ValueError, "full-module"):
                    validate_suite()

    def test_shared_flows_must_be_registered_exactly(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            flow = root / "modules/Example/atlas/atlas-failure.yaml"
            flow.parent.mkdir(parents=True)
            flow.write_text(
                "appId: local\nname: atlas-failure\n---\n- takeScreenshot: failure\n"
            )
            case = {
                "id": "atlas-failure",
                "kind": "render",
                "previewScope": "module",
                "screenshots": ["failure"],
                "flow": str(flow.relative_to(root)),
            }
            with (
                patch("artifacts.TEST", root),
                patch("artifacts.cases", return_value=[case]),
            ):
                self.assertEqual(validate_suite(), [case])
                flow.with_name("unregistered.yaml").write_text(flow.read_text())
                with self.assertRaisesRegex(
                    ValueError, "Unregistered or missing flows"
                ):
                    validate_suite()
