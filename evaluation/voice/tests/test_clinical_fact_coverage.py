from __future__ import annotations

from evaluation.voice.clinical_fact_coverage import clinical_description_coverage


def test_prefix_does_not_hide_complete_clinical_content() -> None:
    result = clinical_description_coverage(
        "right ventricle: 49 mm. No additional abnormality.",
        "Imaging findings: right ventricle: 49 mm. No additional abnormality.",
    )
    assert result["completeLiteralContent"] is True
    assert result["missingCriticalTokens"] == []


def test_missing_negation_and_measurement_are_reported() -> None:
    result = clinical_description_coverage(
        "right ventricle: 49 mm. No additional abnormality.",
        "right ventricle is visible",
    )
    assert result["completeLiteralContent"] is False
    assert result["missingCriticalTokens"] == ["49", "mm", "no"]


def test_wrong_side_is_reported_in_both_directions() -> None:
    result = clinical_description_coverage(
        "левый желудочек: 52 мм. Дополнительных изменений не выявлено.",
        "правый желудочек: 52 мм. Дополнительных изменений не выявлено.",
    )
    assert result["missingCriticalTokens"] == ["левый"]
    assert result["extraCriticalTokens"] == ["правый"]


def test_missing_proposal_counts_all_missing_critical_tokens() -> None:
    result = clinical_description_coverage("left kidney: 35 mm. No abnormality.", None)
    assert result["missingCriticalTokens"] == ["35", "left", "mm", "no"]
