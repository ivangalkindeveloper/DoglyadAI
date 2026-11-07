from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from artifacts import flow_commands
from scenario_coverage import review


class CoverageTests(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.module = self.root / "modules/Example"
        self.module.mkdir(parents=True)
        self.spec = {
            "schemaVersion": 1,
            "module": "Example",
            "source": "ios/Example",
            "cases": [
                {
                    "id": "Example.save",
                    "title": "Save and restore",
                    "preconditions": ["Open editor"],
                    "steps": [{"action": "Save", "expect": "Value persists"}],
                    "covers": ["onSave"],
                    "automation": {"kind": "maestro", "flows": ["save"]},
                }
            ],
        }
        (self.root / "functional.json").write_text(
            json.dumps(
                {"bootstrap": {"id": "save"}, "cases": [], "moduleOrder": ["Example"]}
            )
        )
        self.current = {
            "modules": [
                {"module": "Example", "source": "ios/Example", "actions": ["onSave"]}
            ]
        }

    def inspect(self):
        (self.module / "cases.yaml").write_text(yaml.safe_dump(self.spec))
        with (
            patch("scenario_coverage.TEST", self.root),
            patch("scenario_coverage.inventory", return_value=self.current),
        ):
            return review()

    def test_new_callback_requires_a_scenario(self):
        self.current["modules"][0]["actions"].append("onRetry")
        with self.assertRaisesRegex(ValueError, "unspecified callbacks.*onRetry"):
            self.inspect()

    def test_unknown_flow_cannot_claim_automation(self):
        self.spec["cases"][0]["automation"]["flows"] = ["nonexistent"]
        with self.assertRaisesRegex(ValueError, "Missing automation"):
            self.inspect()

    def test_partial_scenario_keeps_its_missing_requirements(self):
        self.spec["cases"][0]["automation"].update(
            kind="partial", requires=["Restart and assert"]
        )
        self.assertEqual(
            self.inspect()["missingExecution"],
            [{"id": "Example.save", "requires": ["Restart and assert"]}],
        )

    def test_missing_module_cannot_pass_review(self):
        self.current["modules"].append(
            {"module": "New", "source": "ios/New", "actions": []}
        )
        with self.assertRaisesRegex(ValueError, "Modules without specifications.*New"):
            self.inspect()

    def test_nested_subflows_are_checked(self):
        flow = self.root / "flow.yaml"
        flow.write_text(
            "appId: app\n---\n- repeat:\n    times: 2\n    commands:\n    - runFlow: missing.yaml\n"
        )
        with (
            patch("artifacts.TEST", self.root),
            self.assertRaisesRegex(ValueError, "Missing subflow"),
        ):
            flow_commands(flow)

    def test_optional_assertion_in_nested_commands_is_rejected(self):
        flow = self.root / "flow.yaml"
        flow.write_text(
            "appId: app\n---\n- runFlow:\n    commands:\n    - assertVisible:\n        text: Result\n        optional: true\n"
        )
        with (
            patch("artifacts.TEST", self.root),
            self.assertRaisesRegex(ValueError, "Optional command"),
        ):
            flow_commands(flow)

    def test_recursive_helpers_are_rejected(self):
        flow = self.root / "flow.yaml"
        flow.write_text("appId: app\n---\n- runFlow: flow.yaml\n")
        with (
            patch("artifacts.TEST", self.root),
            self.assertRaisesRegex(ValueError, "Recursive subflow"),
        ):
            flow_commands(flow)

    def test_yaml_alias_selector_is_rejected_before_maestro(self):
        flow = self.root / "flow.yaml"
        flow.write_text(
            "appId: app\n---\n- assertVisible: &field\n    id: field\n- tapOn: *field\n"
        )
        with (
            patch("artifacts.TEST", self.root),
            self.assertRaisesRegex(ValueError, "YAML aliases"),
        ):
            flow_commands(flow)


if __name__ == "__main__":
    unittest.main()
