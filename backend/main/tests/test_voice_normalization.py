from __future__ import annotations

# ruff: noqa: RUF001
import pytest

from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.service.normalize_patient_name import normalize_patient_name
from app.service.source_birth_date import source_birth_date
from app.service.validate_voice_form_generation import validate_voice_form_generation
from tests.support.voice_form_parsing.voice_source_localization_test_support import (
    voice_source_localization_test_support,
)


@pytest.mark.parametrize(
    "text,expected",
    [
        ("Дата рождения 23 0 8 2014 год", "2014-08-23"),
        ("Дата рождения: 29 0 2 2000", "2000-02-29"),
        ("Дата рождения: 29 0 2 2001", None),
        ("Дата рождения: 23 0 2014", None),
        ("Дата рождения: 9 23 0 8 2014", None),
        ("Дата рождения: 23 0 8 2014 7", None),
        ("Дата рождения: 23 0 8 2014 или 24 0 8 2014", None),
        ("DOB: 8 0 7 2014", "2014-08-07"),
    ],
)
def test_grouped_numeric_dates_require_one_complete_calendar_date(text: str, expected: str | None) -> None:
    assert source_birth_date(text, localization=voice_source_localization_test_support(text)) == expected


@pytest.mark.parametrize(
    "original,expected",
    [
        ("сидорова анна львовна", "Сидорова Анна Львовна"),
        ("СИДОРОВА АННА", "Сидорова Анна"),
        ("анна-мария O'NEILL", "Анна-Мария O'Neill"),
        ("John McDonald", "John McDonald"),
    ],
)
def test_name_formatting_changes_only_case(original: str, expected: str) -> None:
    assert normalize_patient_name(original) == expected
    assert normalize_patient_name(expected) == expected
    assert expected.casefold() == original.casefold()


def test_source_date_overrides_wrong_model_date_and_name_retains_evidence() -> None:
    text = "Пациент сидорова анна львовна. Дата рождения: 23 0 8 2014 год."
    generated = USVoiceFormGeneration.model_validate(
        [
            {
                "field_id": "patient_name",
                "value": "сидорова анна львовна",
                "evidence": "Пациент сидорова анна львовна",
                "accuracy": "full",
            },
            {
                "field_id": "patient_date_of_birth",
                "value": "2014-08-24",
                "evidence": "Дата рождения: 23 0 8 2014 год",
                "accuracy": "full",
            },
        ]
    )
    fields = {
        item.fieldId.value: item
        for item in validate_voice_form_generation(
            generated, text, localization=voice_source_localization_test_support(text)
        ).proposals
    }
    assert fields["patient_name"].value == "Сидорова Анна Львовна"
    assert fields["patient_date_of_birth"].value == "2014-08-23"
    assert all(item.evidence in text for item in fields.values())


@pytest.mark.parametrize("field,value", [("patient_gender", "женский"), ("patient_date_of_birth", "23 0 8 2014")])
def test_generation_grammar_rejects_noncanonical_values(field: str, value: str) -> None:
    with pytest.raises(ValueError):
        USVoiceFormGeneration.model_validate(
            [{"field_id": field, "value": value, "evidence": "source", "accuracy": "full"}]
        )


@pytest.mark.parametrize(
    "formatted,is_unchanged",
    [
        ("Стенка 2,7 мм. Объём 180 мл. Включений нет.", True),
        ("Стенка 2,8 мм. Объём 180 мл. Включений нет.", False),
        ("Стенка 2,7 мм. Объём 180 мл.", False),
        ("Стенка 2,7 мм. Объём 180 мл. Включения есть.", False),
        ("Стенка 2,7 см. Объём 180 мл. Включений нет.", False),
    ],
)
def test_model_clinical_value_is_retained_and_changed_content_requires_review(
    formatted: str, is_unchanged: bool
) -> None:
    raw = "стенка 2,7 мм объём 180 мл включений нет"
    text = f"Жалобы: жалоб нет. Описание исследования: {raw}"
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "examination_description", "value": formatted, "evidence": raw, "accuracy": "full"}]
    )
    response = validate_voice_form_generation(
        generated, text, localization=voice_source_localization_test_support(text)
    )
    field = next(item for item in response.proposals if item.fieldId.value == "examination_description")
    assert field.value == formatted
    assert field.accuracy.value == ("full" if is_unchanged else "questionable")
    assert field.evidence in text
