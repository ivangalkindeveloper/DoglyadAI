from __future__ import annotations

from evaluation.voice.common import FIELD_IDS
from evaluation.voice.freeform_development import PARTIAL_FIELDS, make_cases


def test_freeform_cases_are_balanced_and_preserve_only_spoken_fields() -> None:
    cases = make_cases()
    assert len(cases) == 124
    assert len({case["id"] for case in cases}) == len(cases)
    for case in cases:
        expected_fields = set(FIELD_IDS if case["scenario"] == "complete" else PARTIAL_FIELDS)
        assert set(case["expectedFields"]) == expected_fields
        assert set(case["expectedSourceQuotes"]) == expected_fields
        assert all(quote in case["spokenText"] for quote in case["expectedSourceQuotes"].values())
        assert "Examination description:" not in case["spokenText"]
        assert "Описание исследования:" not in case["spokenText"]
        assert case["expectedFacts"]
