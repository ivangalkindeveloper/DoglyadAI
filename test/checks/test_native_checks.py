from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from native_checks import ARGUMENT_COUNTS, REQUIRED_TESTS, validate_results


class NativeCheckTests(unittest.TestCase):
    def setUp(self):
        self.summary = dict(
            result="Passed",
            totalTestCount=len(REQUIRED_TESTS),
            passedTests=len(REQUIRED_TESTS),
            failedTests=0,
            skippedTests=0,
            expectedFailures=0,
        )
        self.tree = {
            "testNodes": [
                {
                    "children": [
                        {
                            "nodeType": "Test Case",
                            "nodeIdentifier": name,
                            "result": "Passed",
                            "children": [{"nodeType": "Arguments", "result": "Passed"}
                                         for _ in range(ARGUMENT_COUNTS.get(name, 0))],
                        }
                        for name in REQUIRED_TESTS
                    ]
                }
            ]
        }

    def test_exact_successful_test_is_required(self):
        self.assertEqual(
            validate_results(self.summary, self.tree)["requiredTests"], REQUIRED_TESTS
        )
        self.tree["testNodes"][0]["children"][0]["nodeIdentifier"] = "Different/test()"
        with self.assertRaises(ValueError):
            validate_results(self.summary, self.tree)

    def test_skipped_or_empty_runs_cannot_pass(self):
        for changes in [
            dict(skippedTests=1),
            dict(totalTestCount=0, passedTests=0),
            dict(expectedFailures=1),
        ]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                validate_results({**self.summary, **changes}, self.tree)

    def test_missing_or_skipped_argument_variant_cannot_pass(self):
        case = next(node for node in self.tree["testNodes"][0]["children"] if node["children"])
        case["children"][0]["result"] = "Skipped"
        with self.assertRaises(ValueError):
            validate_results(self.summary, self.tree)
        case["children"].pop()
        with self.assertRaises(ValueError):
            validate_results(self.summary, self.tree)
