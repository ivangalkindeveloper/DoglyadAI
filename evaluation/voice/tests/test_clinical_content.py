from __future__ import annotations

import pytest

from evaluation.voice.scoring.score_clinical_content import score_clinical_content


def _annotation() -> dict:
    return {
        "reviewStatus": "adjudicated",
        "isComplete": True,
        "facts": [
            {"id": "right", "sourceQuote": "Правая почка 112 мм."},
            {"id": "left", "sourceQuote": "Левая почка 98 мм."},
            {"id": "stones", "sourceQuote": "Конкрементов нет.", "acceptedTexts": ["Конкременты не выявлены."]},
        ],
    }


def test_fact_binding_and_added_contradiction_require_adjudication() -> None:
    expected = "Правая почка 112 мм. Левая почка 98 мм. Конкрементов нет."
    for actual in (
        "Правая почка 98 мм. Левая почка 112 мм. Конкрементов нет.",
        "Боль в правой ноге, температуры нет. Левая почка 112 мм. Конкременты выявлены.",
        expected + " Но конкременты выявлены.",
    ):
        score = score_clinical_content(expected, actual, "ru", _annotation())
        assert score["status"] == "requiresAdjudication"
        assert score["isClinicallyEquivalent"] is None


def test_reviewed_equivalence_preserves_all_facts() -> None:
    expected = "Правая почка 112 мм. Левая почка 98 мм. Конкрементов нет."
    score = score_clinical_content(
        expected, "Левая почка 9.8 см. Правая почка 11.2 см. Конкременты не выявлены.", "ru", _annotation()
    )
    assert score["isClinicallyEquivalent"] is True
    assert len(score["matchedFacts"]) == 3


def test_missing_annotation_is_not_a_perfect_clinical_score() -> None:
    score = score_clinical_content("Почка 112 мм", "Почка 112 мм", "ru")
    assert score["status"] == "notAnnotated" and score["isClinicallyEquivalent"] is None
    annotation = {**_annotation(), "reviewStatus": "draft"}
    assert score_clinical_content("same", "same", "en", annotation)["status"] == "pendingReview"


def test_malformed_completeness_cannot_certify_clinical_equivalence() -> None:
    annotation = {**_annotation(), "isComplete": "false"}
    assert score_clinical_content("same", "same", "en", annotation)["isClinicallyEquivalent"] is None
    with pytest.raises(ValueError):
        score_clinical_content("same", "same", "en", {**_annotation(), "facts": []})
