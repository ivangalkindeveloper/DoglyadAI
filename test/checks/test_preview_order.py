from pathlib import Path
import json
import yaml
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from catalog import ordered_previews, generated


class PreviewOrderTests(unittest.TestCase):
    def preview(self, title, module="Example"):
        return {"source": f"{module}Preview.swift", "title": title, "body": "View()"}

    def test_number_order_is_numeric_and_modules_follow_navigation(self):
        previews = [
            self.preview(f"{n} State{n}") for n in [10, 2, 1, 4, 9, 7, 6, 8, 5, 3]
        ]
        previews.append(self.preview("01 Welcome", "Start"))
        ordered = ordered_previews(previews, ["Start", "Example"])
        self.assertEqual(ordered[0]["previewName"], "Welcome")
        self.assertEqual([p["previewOrder"] for p in ordered[1:]], list(range(1, 11)))

    def test_unnamed_and_unnumbered_previews_are_rejected(self):
        for title in ["", "OnBoardingInitialState", "0 First", "1 "]:
            with self.subTest(title=title), self.assertRaises(ValueError):
                ordered_previews([self.preview(title)], ["Example"])

    def test_duplicates_and_gaps_are_rejected(self):
        for names in [["1 First", "01 Second"], ["1 First", "3 Second"]]:
            with self.subTest(names=names), self.assertRaises(ValueError):
                ordered_previews([self.preview(n) for n in names], ["Example"])

    def test_renumbering_preserves_the_name_used_for_launch_identity(self):
        first = ordered_previews(
            [self.preview("01 First"), self.preview("02 Second")], ["Example"]
        )
        second = ordered_previews(
            [self.preview("02 First"), self.preview("01 Second")], ["Example"]
        )
        self.assertEqual(first[0]["previewName"], second[1]["previewName"])

    def test_russian_error_previews_wait_for_the_message_before_capture(self):
        output = generated()
        atlas = json.loads(output["catalog.json"])["atlas"]
        cases = [
            case
            for case in atlas
            if case["screen"] == "SubscriptionRecovery" and "SubscriptionRecoveryErrorState" in case["title"] and not case["title"].endswith(" ScrollEnd")
        ]
        self.assertEqual(len(cases), 2)
        for case in cases:
            commands = list(yaml.safe_load_all(output[case["flow"]]))[1]
            waits = [
                command
                for command in commands
                if isinstance(command, dict)
                and command.get("extendedWaitUntil", {}).get("visible", {}).get("id")
                == "message.error"
            ]
            self.assertEqual(len(waits), 1)
            self.assertLess(commands.index(waits[0]), len(commands) - 1)
            self.assertIn("takeScreenshot", commands[-1])

    def test_optional_recent_types_use_silent_full_module_fallback(self):
        output = generated()
        atlas = json.loads(output["catalog.json"])["atlas"]
        case = next(
            case
            for case in atlas
            if case["screen"] == "SelectUSExaminationType" and "FirstUse" in case["title"] and not case["title"].endswith(" ScrollEnd")
        )
        self.assertEqual(case["previewScope"], "module")
        commands = list(yaml.safe_load_all(output[case["flow"]]))[1]
        self.assertIn({"assertNotVisible": "^Недавние$"}, commands)
        self.assertIn({"assertNotVisible": {"id": "message.error"}}, commands)
        self.assertFalse(any(
            isinstance(command, dict)
            and command.get("extendedWaitUntil", {}).get("visible", {}).get("id") == "message.error"
            for command in commands
        ))

    def test_management_previews_wait_for_the_final_layout(self):
        output = generated()
        atlas = json.loads(output["catalog.json"])["atlas"]
        cases = [case for case in atlas if case["screen"] == "ManageSubscription"]
        self.assertGreater(len(cases), 0)
        for case in cases:
            commands = list(yaml.safe_load_all(output[case["flow"]]))[1]
            self.assertEqual(commands[-2], "waitForAnimationToEnd")
            self.assertIn("takeScreenshot", commands[-1])
