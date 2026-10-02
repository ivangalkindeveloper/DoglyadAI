from __future__ import annotations

from evaluation.voice.common import FIELD_IDS
from evaluation.voice.generate import make_corpus
from evaluation.voice.phrase_holdout import spoken_segments


def test_phrase_holdout_uses_distinct_control_values_and_eight_complete_fields() -> None:
    regression, control = make_corpus()
    original_ids = {case["id"] for case in regression}
    selected = [case for case in control if case["scenario"] == "findings_first"]
    assert len(selected) == 62
    assert not original_ids.intersection(case["id"] for case in selected)
    for case in selected:
        segments = spoken_segments(case)
        assert len(segments) == len(FIELD_IDS)
        assert case["expectedFields"]["patientName"] in " ".join(segments)
        assert case["expectedSourceQuotes"]["patientComplaints"] in " ".join(segments)
        assert segments[0].startswith(
            "Examination description:" if case["locale"] == "en" else "Описание исследования:"
        )
