from __future__ import annotations

from collections import Counter

from evaluation.voice.common import FIELD_IDS, LABELS
from evaluation.voice.voice_blind_v3 import PARTIAL_FIELDS, make_cases, spoken_segments


def test_reordered_pack_keeps_form_labels_but_never_uses_the_sheet_order() -> None:
    cases = make_cases()
    assert len(cases) == 124
    assert Counter((case["locale"], case["scenario"]) for case in cases) == {
        (locale, scenario): 31 for locale in ("en", "ru") for scenario in ("complete", "partial")
    }
    for case in cases:
        labels = dict(zip(FIELD_IDS, LABELS[case["locale"]], strict=True))
        included = [field for field in FIELD_IDS if field in case["expectedFields"]]
        dictated_labels = [segment.split(":", 1)[0] for segment in spoken_segments(case)]
        assert len(dictated_labels) == len(set(dictated_labels)) == len(included)
        assert set(dictated_labels) == {labels[field] for field in included}
        assert dictated_labels[0] == labels["examinationDescription"]
        assert dictated_labels != [labels[field] for field in included]
        if case["scenario"] == "complete":
            assert set(included) == set(FIELD_IDS)
        else:
            assert set(included) == set(PARTIAL_FIELDS)
        assert all(quote in case["spokenText"] for quote in case["expectedSourceQuotes"].values())
