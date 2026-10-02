from __future__ import annotations

from collections import Counter

from evaluation.voice.voice_blind_v3 import NAMES, PARTIAL_FIELDS, make_cases, spoken_segments


def test_blind_forms_are_balanced_and_partial_gold_omits_untouched_fields() -> None:
    cases = make_cases()
    assert len(cases) == 124
    assert Counter((case["locale"], case["scenario"]) for case in cases) == {
        (locale, scenario): 31 for locale in ("en", "ru") for scenario in ("complete", "partial")
    }
    for case in cases:
        segments = spoken_segments(case)
        assert len(segments) == (8 if case["scenario"] == "complete" else 4)
        assert segments[0].startswith(
            "Examination description:" if case["locale"] == "en" else "Описание исследования:"
        )
        if case["scenario"] == "partial":
            assert set(case["expectedFields"]) == set(PARTIAL_FIELDS)
            assert "patientName" not in case["expectedSourceQuotes"]
        else:
            assert (
                case["expectedFields"]["patientName"] in NAMES[case["locale"]][case["expectedFields"]["patientGender"]]
            )
