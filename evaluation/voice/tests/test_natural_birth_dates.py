from __future__ import annotations

import copy

import pytest

from evaluation.voice.natural_birth_dates import natural_date_text, render_birth_date


@pytest.mark.parametrize(
    "value,locale,spoken,expected",
    [
        ("1978-08-01", "ru", False, "1 августа 1978 года"),
        ("1978-08-01", "ru", True, "первое августа тысяча девятьсот семьдесят восьмого года"),
        ("1980-03-12", "ru", True, "двенадцатое марта тысяча девятьсот восьмидесятого года"),
        ("2000-02-29", "ru", True, "двадцать девятое февраля двухтысячного года"),
        ("2026-09-03", "ru", True, "третье сентября две тысячи двадцать шестого года"),
        ("1978-08-01", "en", False, "August 1, 1978"),
        ("1978-08-01", "en", True, "the first of August nineteen seventy eight"),
        ("2000-02-29", "en", True, "the twenty ninth of February two thousand"),
        ("2005-12-30", "en", True, "the thirtieth of December two thousand five"),
        ("1981-07-31", "en", True, "the thirty first of July nineteen eighty one"),
    ],
)
def test_natural_birth_dates(value: str, locale: str, spoken: bool, expected: str) -> None:
    assert render_birth_date(value, locale, spoken=spoken) == expected


def test_rendering_does_not_change_truth_or_other_text() -> None:
    case = {
        "id": "independent-date",
        "locale": "ru",
        "inputText": "На приёме Иван, один девять семь восемь, ноль восемь, ноль один года рождения. Жалоб нет.",
        "expectedFields": {"patientDateOfBirth": "1978-08-01", "patientComplaints": "Жалоб нет"},
    }
    before = copy.deepcopy(case)
    assert natural_date_text(case, spoken=False) == "На приёме Иван, 1 августа 1978 года рождения. Жалоб нет."
    assert case == before


def test_partial_dictation_does_not_gain_birth_date() -> None:
    case = {"inputText": "Жалоб нет.", "expectedFields": {"patientComplaints": "Жалоб нет"}}
    assert natural_date_text(case, spoken=True) == "Жалоб нет."


def test_invalid_calendar_date_is_not_rendered() -> None:
    with pytest.raises(ValueError):
        render_birth_date("1978-02-30", "ru", spoken=True)
