import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from report_evidence import verify


class ReportEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.original = dict(
            id="old",
            actual=True,
            modelId="old-model",
            status="completed",
            description="Original description",
            conclusion="Original conclusion",
            recommendations="Original recommendation",
            descriptionRemarks=None,
        )
        self.before = dict(
            id="report",
            examinationSha256="exam",
            photoCount=1,
            versions=[self.original],
        )
        self.current = {
            **self.original,
            "id": "new",
            "modelId": "new-model",
            "recommendations": None,
        }
        self.failed = {
            **self.current,
            "id": "failed",
            "actual": False,
            "status": "failed",
            "description": "",
            "conclusion": "",
        }
        self.after = {
            **self.before,
            "versions": [{**self.original, "actual": False}, self.failed, self.current],
        }
        self.expected = dict(
            actualModel="new-model",
            clipboardModel="old-model",
            versionCount=3,
            completedCount=2,
            failedCount=1,
            preserveExamination=True,
            distinctResponses=True,
        )
        catalog = json.loads(
            (
                Path(__file__).resolve().parents[2]
                / "backend/main/config/development/ru/l10n_application.json"
            ).read_text()
        )
        self.clipboard = (
            catalog["reportDescriptionTitle"]
            + "\nOriginal description\n\n"
            + catalog["reportConclusionTitle"]
            + "\nOriginal conclusion\n\n"
            + catalog["reportRecommendationsTitle"]
            + "\nOriginal recommendation"
        )

    def test_previous_response_copy_matches_full_saved_text(self):
        proof = verify(self.before, self.after, self.expected, self.clipboard)
        self.assertEqual(proof["copiedVersionId"], "old")
        self.assertNotIn("Original description", str(proof))
        with self.assertRaises(ValueError):
            verify(self.before, self.after, self.expected, self.clipboard + " altered")

    def test_regeneration_cannot_replace_original_data_or_drop_versions(self):
        for field, value in [
            ("id", "another"),
            ("examinationSha256", "changed"),
            ("versions", [self.current]),
        ]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                verify(
                    self.before,
                    {**self.after, field: value},
                    self.expected,
                    self.clipboard,
                )
        altered = copy.deepcopy(self.after)
        altered["versions"][0]["conclusion"] = "changed"
        with self.assertRaisesRegex(ValueError, "changed or lost"):
            verify(self.before, altered, self.expected, self.clipboard)

    def test_incomplete_or_identical_versions_cannot_satisfy_copy_checks(self):
        altered = copy.deepcopy(self.after)
        altered["versions"][2]["status"] = "failed"
        with self.assertRaises(ValueError):
            verify(self.before, altered, self.expected, self.clipboard)
        altered = copy.deepcopy(self.after)
        altered["versions"][2]["recommendations"] = "Original recommendation"
        with self.assertRaisesRegex(ValueError, "identical"):
            verify(self.before, altered, self.expected, self.clipboard)
