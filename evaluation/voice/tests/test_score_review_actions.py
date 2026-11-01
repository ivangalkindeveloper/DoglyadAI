from __future__ import annotations

from evaluation.voice.scoring.score_review_actions import score_review_actions


def test_uncertain_fragment_does_not_justify_discarding_reliable_fields() -> None:
    expected = {"patientWeightKG": {"action": "review"}, "examinationNumber": {"action": "accept"}}
    result = {
        "status": "ok",
        "fields": {"examinationNumber": "0184"},
        "reviewFieldIds": ["patientWeightKG"],
        "automaticFieldIds": ["examinationNumber"],
    }
    assert score_review_actions(expected, result, {"examinationNumber": True})["matched"] == 2
    result["fields"] = {}
    result["automaticFieldIds"] = []
    assert score_review_actions(expected, result, {"examinationNumber": False})["matched"] == 1
    result["reviewFieldIds"] = []
    assert score_review_actions(expected, result, {"examinationNumber": False})["matched"] == 0
