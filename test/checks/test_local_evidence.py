import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from local_evidence import verify_local


class LocalEvidenceTests(unittest.TestCase):
    def test_cancellation_requires_real_rows_and_unchanged_contents(self):
        before = dict(
            reports=dict(count=2, sha256="a"), templates=dict(count=1, sha256="b")
        )
        expected = dict(
            preserved=["reports", "templates"],
            minimumBefore=dict(reports=1, templates=1),
        )
        self.assertEqual(verify_local(before, before, expected)["status"], "passed")
        for after in [
            dict(before, reports=dict(count=2, sha256="modified")),
            dict(before, templates=dict(count=0, sha256="empty")),
        ]:
            with self.assertRaises(ValueError):
                verify_local(before, after, expected)
        empty = dict(before, reports=dict(count=0, sha256="empty"))
        with self.assertRaises(ValueError):
            verify_local(empty, empty, expected)

    def test_history_clear_preserves_templates_and_settings(self):
        before = dict(
            reports=dict(count=2, sha256="a"), templates=dict(count=1, sha256="b")
        )
        after = dict(before, reports=dict(count=0, sha256="empty"))
        expected = dict(
            preserved=["templates"], cleared=["reports"], minimumBefore=dict(reports=1)
        )
        self.assertEqual(verify_local(before, after, expected)["status"], "passed")
        with self.assertRaises(ValueError):
            verify_local(before, before, expected)
        with self.assertRaises(ValueError):
            verify_local(
                before,
                dict(after, reports=dict(count=0, rows=1, sha256="orphan")),
                expected,
            )

    def test_retry_must_add_one_report_not_one_record_per_attempt(self):
        before = dict(reports=dict(count=2))
        expected = dict(countDelta=dict(reports=1))
        self.assertEqual(
            verify_local(before, dict(reports=dict(count=3)), expected)["status"],
            "passed",
        )
        for count in [2, 4]:
            with self.assertRaises(ValueError):
                verify_local(before, dict(reports=dict(count=count)), expected)

    def test_gallery_requires_the_selected_aspects_not_only_a_photo_count(self):
        expected = dict(draftPhotoAspects=["landscape", "portrait", "square"])
        self.assertEqual(
            verify_local(
                {},
                dict(draftPhotoAspects=["square", "portrait", "landscape"]),
                expected,
            )["status"],
            "passed",
        )
        for aspects in [["landscape"] * 3, ["landscape", "portrait"], []]:
            with self.assertRaises(ValueError):
                verify_local({}, dict(draftPhotoAspects=aspects), expected)

    def test_full_clear_removes_user_choices_and_restores_default_ai_values(self):
        expected = dict(
            preferencesCleared=["userEmail", "isPhotoRemarks"],
            settingsAIValues=dict(isMarkdown=False, temperature=None, maxTokens=None),
        )
        after = dict(
            presentPreferences=["settingsAI", "isOnBoardingCompleted"],
            settingsAIValues=dict(isMarkdown=False, temperature=None, maxTokens=None),
        )
        self.assertEqual(verify_local({}, after, expected)["status"], "passed")
        for changed in [
            dict(after, presentPreferences=["userEmail"]),
            dict(
                after,
                settingsAIValues=dict(isMarkdown=True, temperature=0.7, maxTokens=1024),
            ),
        ]:
            with self.assertRaises(ValueError):
                verify_local({}, changed, expected)
