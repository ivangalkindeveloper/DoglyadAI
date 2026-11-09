from pathlib import Path
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from catalog import ROOT, extract


class PreviewPresentationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.previews = extract()

    def test_full_module_names_identify_real_states_and_english_scenarios(self):
        for preview in self.previews:
            feature = Path(preview["source"]).stem.removesuffix("Preview")
            if feature + "PreviewView(" not in preview["body"] and feature != "ApplicationSplash":
                continue
            with self.subTest(title=preview["title"]):
                self.assertRegex(preview["title"], r"^\d+ [A-Za-z]\w*State(?: [A-Za-z][A-Za-z0-9]*)+$")
                state = preview["title"].split()[1]
                self.assertTrue(list((ROOT / "ios/Doglyad").rglob(state + ".swift")), state)
                direct = re.search(r"\bstate:\s*([A-Za-z]\w*State)\s*\(", preview["body"])
                if direct:
                    self.assertEqual(direct[1], state)

    def test_scroll_end_is_a_companion_with_identical_state_and_data(self):
        previous = None
        modules = set()
        for preview in self.previews:
            if preview["title"].endswith(" ScrollEnd"):
                with self.subTest(title=preview["title"]):
                    self.assertIsNotNone(previous)
                    self.assertEqual(preview["source"], previous["source"])
                    self.assertEqual(preview["title"].split(" ", 1)[1].removesuffix(" ScrollEnd"), previous["title"].split(" ", 1)[1])
                    self.assertEqual(re.sub(r"\s+", "", preview["body"].replace(".previewScrollToEnd()", "")), re.sub(r"\s+", "", previous["body"]))
                modules.add(Path(preview["source"]).stem.removesuffix("Preview"))
            previous = preview
        self.assertTrue({"Scan", "Settings", "History", "WebDocument", "Paywall", "SelectUSExaminationType", "ScanSpeech"} <= modules)

    def test_legal_loading_has_consent_and_checked_choice_exists(self):
        legal = [p for p in self.previews if Path(p["source"]).stem == "LegalUpdatePreview"]
        self.assertFalse(any("LoadingState" in p["title"] for p in legal))
        self.assertTrue(any("LegalUpdateAwaitingAcceptanceState ConsentSelected" in p["title"] and "isLegalAccepted: true" in p["body"] for p in legal))

    def test_first_examination_choice_precedes_maximum_recent_history(self):
        choices = [p for p in self.previews if Path(p["source"]).stem == "SelectUSExaminationTypePreview" and not p["title"].endswith(" ScrollEnd")]
        self.assertEqual([p["title"].split()[-1] for p in choices], ["FirstUse", "MaximumRecentTypes"])
        self.assertIn("isRecentSectionVisible: false", choices[0]["body"])
        self.assertIn("isRecentSectionVisible: true", choices[1]["body"])
