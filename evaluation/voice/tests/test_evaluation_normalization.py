from __future__ import annotations

import pytest

from evaluation.voice.scoring.normalize_evaluation_text import normalize_evaluation_text
from evaluation.voice.scoring.normalize_asr_text import normalize_asr_text
from evaluation.voice.scoring.score_candidate import score_fields
from evaluation.voice.scoring.score_ios import _equal
from evaluation.voice.scoring.spoken_wer import spoken_normalized_wer
from evaluation.voice.scoring.word_error_counts import word_error_counts


@pytest.mark.parametrize(
    ("reference", "actual", "locale"),
    [
        ("Вес шестьдесят две целых четыре десятых килограмма", "Вес 62,4 кг", "ru"),
        ("Вес шестьдесят два целых четыре десятых килограммов", "Вес 62.4 кг", "ru"),
        ("Weight sixty two point four kilograms", "Weight 62.4 kg", "en"),
        ("Размер ноль целых пять сотых миллиметра", "Размер 0.05 мм", "ru"),
        ("Size zero point zero five millimeters", "Size 0.05 mm", "en"),
        (
            "Дата рождения девятое февраля тысяча девятьсот восемьдесят седьмого года",
            "Дата рождения 9 февраля 1987 года",
            "ru",
        ),
        ("Born on the sixteenth of February nineteen eighty four", "Born on February 16, 1984", "en"),
        ("Дата рождения двадцать девятого февраля двухтысячного года", "Дата рождения 2000-02-29", "ru"),
        ("Площадь двенадцать квадратных миллиметров", "Площадь 12 мм2", "ru"),
    ],
)
def test_equivalent_display_forms(reference: str, actual: str, locale: str) -> None:
    assert spoken_normalized_wer(reference, actual, locale) == 0
    assert spoken_normalized_wer(actual, reference, locale) == 0


@pytest.mark.parametrize(
    ("reference", "actual"),
    [
        ("Киста 1,2 мм", "Киста 1–2 мм"),
        ("Киста 1,2 мм", "Киста 1 2 мм"),
        ("Сдвиг +5 мм", "Сдвиг -5 мм"),
        ("Размер 1/2 см", "Размер 1 2 см"),
        ("Киста 12 мм", "Киста 1,2 мм"),
        ("Узел 5 мм", "Узел 5 см"),
        ("Площадь 12 мм2", "Площадь 12 мм"),
        ("Конкрементов нет", "Конкременты есть"),
    ],
)
def test_clinical_changes_are_not_normalized_away(reference: str, actual: str) -> None:
    assert not _equal("examinationDescription", reference, actual)
    score = score_fields(
        {"examinationDescription": reference},
        {"fields": {"examinationDescription": actual}, "warnings": {}},
        locale="ru",
        normalize_description=True,
    )
    assert not score["equivalentExactCase"]


def test_conversion_preserves_value_and_dimension() -> None:
    assert normalize_evaluation_text("Почка 112 мм", "ru", is_convert_units=True) == normalize_evaluation_text(
        "Почка 11.2 см", "ru", is_convert_units=True
    )
    assert normalize_evaluation_text("Дата 03/04/1990", "en") != normalize_evaluation_text("Дата April 3, 1990", "en")


@pytest.mark.parametrize(
    ("reference", "actual"),
    [
        ("11 by 5 cm", "11 by 50 mm"),
        ("1-2 cm", "1-20 mm"),
        ("5 cm²", "50 mm²"),
        ("5 kg/m²", "5000 g/m²"),
        ("5 cm/min", "50 mm/min"),
        ("11 5 cm", "11 50 mm"),
        ("5±1 cm", "5±10 mm"),
        ("5 cm^2", "50 mm^2"),
    ],
)
def test_shared_and_derived_units_are_not_partially_converted(reference: str, actual: str) -> None:
    assert normalize_evaluation_text(reference, "en", is_convert_units=True) != normalize_evaluation_text(
        actual, "en", is_convert_units=True
    )


def test_alignment_reports_counts_and_silence_without_division_by_zero() -> None:
    result = word_error_counts(("a", "b", "c"), ("a", "d"))
    assert result["substitutions"] == result["deletions"] == 1
    assert result["errors"] == 2 and result["referenceWords"] == 3
    silence = word_error_counts((), ("invented", "words"))
    assert silence["wer"] is None and silence["insertions"] == 2


@pytest.mark.parametrize("symbol", ["≤", "≥", "≈", "~", "±", "°", "*"])
def test_clinically_meaningful_symbols_are_not_erased(symbol: str) -> None:
    expected, actual = f"Размер {symbol}5 мм", "Размер 5 мм"
    assert not _equal("examinationDescription", expected, actual)
    assert normalize_evaluation_text(expected, "ru") != normalize_evaluation_text(actual, "ru")


def test_explicit_angles_have_a_preserved_unit() -> None:
    assert normalize_evaluation_text("Угол 63 градуса", "ru") == normalize_evaluation_text("Угол 63°", "ru")


def test_asr_date_spelling_and_report_punctuation_are_not_medical_errors() -> None:
    reference = "Печень: сто сорок два миллиметра. Дата рождения: один девять семь три, ноль семь, ноль восемь. Номер исследования: ноль один шесть."
    actual = "Печень – 142 мм. Дата рождения – 1-9-7-3-0-7-0-8. Номер исследования – 0-1-6."
    assert spoken_normalized_wer(reference, actual, "ru") == 0
    assert normalize_evaluation_text("Сдвиг – 5 мм", "ru") != normalize_evaluation_text("Сдвиг 5 мм", "ru")
    assert normalize_asr_text("Размер 1 – 2 мм", "ru") != normalize_asr_text("Размер 12 мм", "ru")
    assert normalize_asr_text("Сдвиг −5 мм", "ru") != normalize_asr_text("Сдвиг +5 мм", "ru")
    assert normalize_asr_text("Дата рождения 03-04-1990", "ru") != normalize_asr_text("Дата рождения 1990-04-03", "ru")
    assert normalize_asr_text("Пациент 1-9-8-4-0-9-1-1 года рождения", "ru") == normalize_asr_text(
        "Пациент 1984-09-11 года рождения", "ru"
    )
