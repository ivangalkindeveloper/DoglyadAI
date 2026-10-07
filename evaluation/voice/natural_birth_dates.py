from __future__ import annotations

from datetime import date
from typing import Any

from evaluation.voice.audio_script_v2 import _spoken_digits
from evaluation.voice.common import _number_words

VERSION = "natural-birth-dates-v2"
MONTHS = {
    "en": (
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
    ),
    "ru": (
        "января",
        "февраля",
        "марта",
        "апреля",
        "мая",
        "июня",
        "июля",
        "августа",
        "сентября",
        "октября",
        "ноября",
        "декабря",
    ),
}
_RU_ORDINAL_STEMS = (
    "",
    "перв",
    "втор",
    "треть",
    "четвёрт",
    "пят",
    "шест",
    "седьм",
    "восьм",
    "девят",
    "десят",
    "одиннадцат",
    "двенадцат",
    "тринадцат",
    "четырнадцат",
    "пятнадцат",
    "шестнадцат",
    "семнадцат",
    "восемнадцат",
    "девятнадцат",
)
_RU_TENS_ORDINAL_STEMS = {
    20: "двадцат",
    30: "тридцат",
    40: "сороков",
    50: "пятидесят",
    60: "шестидесят",
    70: "семидесят",
    80: "восьмидесят",
    90: "девяност",
}
_EN_ORDINALS = (
    "",
    "first",
    "second",
    "third",
    "fourth",
    "fifth",
    "sixth",
    "seventh",
    "eighth",
    "ninth",
    "tenth",
    "eleventh",
    "twelfth",
    "thirteenth",
    "fourteenth",
    "fifteenth",
    "sixteenth",
    "seventeenth",
    "eighteenth",
    "nineteenth",
    "twentieth",
)


def _ru_ordinal(value: int, *, genitive: bool) -> str:
    if not 1 <= value <= 99:
        raise ValueError(f"Unsupported ordinal: {value}")
    if value == 3:
        return "третьего" if genitive else "третье"
    if value < 20:
        stem = _RU_ORDINAL_STEMS[value]
    elif value % 10 == 0:
        stem = _RU_TENS_ORDINAL_STEMS[value]
    else:
        return _number_words(value // 10 * 10, "ru") + " " + _ru_ordinal(value % 10, genitive=genitive)
    return stem + ("ого" if genitive else "ое")


def _spoken_year(year: int, locale: str) -> str:
    if not 1900 <= year <= 2099:
        raise ValueError(f"Unsupported birth year: {year}")
    remainder = year % 100
    if locale == "ru":
        if year == 1900:
            return "тысяча девятисотого"
        if year == 2000:
            return "двухтысячного"
        prefix = "тысяча девятьсот" if year < 2000 else "две тысячи"
        return prefix + " " + _ru_ordinal(remainder, genitive=True)
    if locale != "en":
        raise ValueError(f"Unsupported locale: {locale}")
    if year == 1900:
        return "nineteen hundred"
    if year < 2000:
        middle = " oh " if remainder < 10 else " "
        return "nineteen" + middle + _number_words(remainder, "en")
    return "two thousand" + (" " + _number_words(remainder, "en") if remainder else "")


def render_birth_date(value: str, locale: str, *, spoken: bool, include_year_suffix: bool = True) -> str:
    """Render independently fixed ISO truth as an ordinary dictated birth date."""
    birthday = date.fromisoformat(value)
    month = MONTHS[locale][birthday.month - 1]
    if locale == "ru":
        day = _ru_ordinal(birthday.day, genitive=False) if spoken else str(birthday.day)
        year = _spoken_year(birthday.year, locale) if spoken else str(birthday.year)
        return f"{day} {month} {year}" + (" года" if include_year_suffix else "")
    if spoken:
        day = (
            _EN_ORDINALS[birthday.day]
            if birthday.day <= 20
            else "thirtieth"
            if birthday.day == 30
            else _number_words(birthday.day // 10 * 10, "en") + " " + _EN_ORDINALS[birthday.day % 10]
        )
        return f"the {day} of {month} {_spoken_year(birthday.year, locale)}"
    return f"{month} {birthday.day}, {birthday.year}"


def natural_date_text(case: dict[str, Any], *, spoken: bool) -> str:
    """Replace only the legacy digit-by-digit date; never alter expected fields."""
    text: str = case["inputText"]
    birthday = case["expectedFields"].get("patientDateOfBirth")
    if birthday is None:
        return text
    locale = case["locale"]
    legacy = ", ".join(_spoken_digits(part, locale) for part in birthday.split("-"))
    if text.count(legacy) != 1:
        raise ValueError(f"Expected exactly one legacy birth date in {case['id']}")
    suffix_already_present = locale == "ru" and f"{legacy} года рождения" in text
    replacement = render_birth_date(birthday, locale, spoken=spoken, include_year_suffix=not suffix_already_present)
    return text.replace(legacy, replacement, 1)
