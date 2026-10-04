from __future__ import annotations

import pytest

from evaluation.voice.report import _field_nonregression, _gate
from evaluation.voice.score_candidate import require_exact_gold_text, score_fields
from evaluation.voice.score_ios import _equal


def test_text_scoring_ignores_typography_but_preserves_facts() -> None:
    assert _equal("examinationDescription", "Right kidney: 12.5 mm. No lesion.", "right kidney 12,5 mm no lesion")
    assert not _equal("examinationDescription", "Right kidney: 12.5 mm. No lesion.", "left kidney 12.5 mm lesion")
    assert not _equal("examinationDescription", "Right kidney: 12.5 mm.", "right kidney 125 mm")
    assert not _equal("examinationNumber", "007", "7")


def test_wrong_critical_value_without_warning_blocks_safety_gate() -> None:
    expected = {"examinationDescription": "No lesion on the right. 12 mm."}
    actual = {"fields": {"examinationDescription": "Lesion on the left. 21 mm."}, "warnings": {}}

    score = score_fields(expected, actual)

    assert score["exactCase"] is False
    assert score["proposedFields"] == ["examinationDescription"]
    assert score["unnoticedWrongFields"] == ["examinationDescription"]


def test_wrong_full_accuracy_is_counted_separately() -> None:
    score = score_fields(
        {"patientWeightKG": 82},
        {"fields": {"patientWeightKG": 72}, "warnings": {}, "accuracies": {"patientWeightKG": "full"}},
    )
    assert score["wrongFullFields"] == ["patientWeightKG"]


def test_warning_does_not_turn_wrong_value_into_correct_value() -> None:
    expected = {"examinationDescription": "No lesion on the right."}
    actual = {
        "fields": {"examinationDescription": "Lesion on the right."},
        "warnings": {"examinationDescription": ["negationMismatch"]},
    }

    score = score_fields(expected, actual)

    assert score["exactCase"] is False
    assert score["unnoticedWrongFields"] == []
    assert score["warnedFields"] == ["examinationDescription"]


def test_automatic_fields_are_scored_against_missing_and_wrong_expected_values() -> None:
    expected = {"patientWeightKG": 72}
    parse = {
        "fields": {"patientName": "Melanie", "patientWeightKG": 72},
        "warnings": {},
        "automaticFieldIds": ["patientName", "patientWeightKG"],
    }

    score = score_fields(expected, parse)

    assert score["automaticFields"] == ["patientName", "patientWeightKG"]
    assert score["wrongAutomaticFields"] == ["patientName"]
    assert score["falseAutomaticFields"] == ["patientName"]
    assert score["falseFilledFields"] == ["patientName"]


def test_v2_reports_spelling_equivalence_separately_from_strict_exactness() -> None:
    expected = {"examinationDescription": "Left ventricle fifty four mm. No additional abnormality."}
    proposed = {
        "fields": {"examinationDescription": "left ventricle 54 millimeters no additional abnormality"},
        "warnings": {},
    }
    score = score_fields(expected, proposed, locale="en", normalize_description=True)
    assert score["exactCase"] is False
    assert score["equivalentExactCase"] is True
    assert score["unnoticedWrongFields"] == ["examinationDescription"]
    assert score["equivalentUnnoticedWrongFields"] == []

    proposed["fields"]["examinationDescription"] = "left ventricle 54 millimeters additional abnormality"
    score = score_fields(expected, proposed, locale="en", normalize_description=True)
    assert score["equivalentExactCase"] is False
    assert score["equivalentUnnoticedWrongFields"] == ["examinationDescription"]


def test_v2_oracle_accepts_spelled_number_but_not_wrong_number() -> None:
    expected = {"examinationDescription": "Right ventricle 49 mm. No lesion."}
    proposed = {
        "fields": {"examinationDescription": "Right ventricle forty nine millimeters. No lesion."},
        "warnings": {},
    }
    assert score_fields(expected, proposed, locale="en", normalize_description=True)["equivalentExactCase"]

    proposed["fields"]["examinationDescription"] = "Right ventricle forty eight millimeters. No lesion."
    assert not score_fields(expected, proposed, locale="en", normalize_description=True)["equivalentExactCase"]


def test_missing_results_remain_unmeasured() -> None:
    assert _gate(None, "missing")["status"] == "unmeasured"
    assert _field_nonregression(None, None)["pairedCases"] == 0


def test_gold_text_runner_fails_on_wrong_or_missing_parse() -> None:
    summary = {
        "inputSource": "originalText",
        "requestedCases": 3,
        "scoredCases": [
            {"id": "exact", "goldTextStatus": "ok", "goldText": {"exactCase": True}},
            {"id": "wrong", "goldTextStatus": "ok", "goldText": {"exactCase": False}},
            {"id": "missing", "goldTextStatus": "failed"},
        ],
    }

    with pytest.raises(ValueError, match="2/3 cases: wrong, missing"):
        require_exact_gold_text(summary)

    summary["inputSource"] = "asrReplay"
    require_exact_gold_text(summary)


def test_v2_gold_gate_uses_numeric_and_unit_equivalence() -> None:
    summary = {
        "inputSource": "originalText",
        "audioMode": "extended-v2",
        "requestedCases": 1,
        "scoredCases": [
            {
                "id": "spoken-measurement",
                "goldTextStatus": "ok",
                "goldText": {"exactCase": False, "equivalentExactCase": True},
            }
        ],
    }
    require_exact_gold_text(summary)

    summary["scoredCases"][0]["goldText"]["equivalentExactCase"] = False
    with pytest.raises(ValueError, match="spoken-measurement"):
        require_exact_gold_text(summary)
