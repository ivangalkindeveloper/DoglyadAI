from __future__ import annotations

import re
from typing import Any

from evaluation.voice.common import FIELD_IDS, LABELS, _number_words

DIGIT_WORDS = {
    "en": ("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"),
    "ru": ("ноль", "один", "два", "три", "четыре", "пять", "шесть", "семь", "восемь", "девять"),
}
SPOKEN_UNITS = {
    "en": ((r"\bcm/s\b", "centimeters per second"), (r"\bmm\b", "millimeters"), (r"\bml\b", "milliliters")),
    "ru": ((r"\bсм/с\b", "сантиметров в секунду"), (r"\bмм\b", "миллиметров"), (r"\bмл\b", "миллилитров")),
}


def _spoken_digits(value: str, locale: str) -> str:
    if not value.isascii() or not value.isdigit():
        raise ValueError(f"Expected ASCII digits, got {value!r}")
    return " ".join(DIGIT_WORDS[locale][int(digit)] for digit in value)


def _spoken_number(value: str, locale: str) -> str:
    return _number_words(int(value), locale)


def _description(value: str, locale: str) -> str:
    # Keep correction words, sides and negation untouched. Only pronunciation of
    # a literal integer and its unit changes; the expected form stays canonical.
    value = re.sub(
        r"(?<![\w.,])\d{1,3}(?!\w)(?![.,]\d)",
        lambda match: _spoken_number(match.group(), locale),
        value,
    )
    for pattern, spoken in SPOKEN_UNITS[locale]:
        value = re.sub(pattern, spoken, value, flags=re.IGNORECASE)
    return value


def make_audio_segments(case: dict[str, Any]) -> list[str]:
    """Render the field phrases of one preselected structured case.

    The function never derives expected fields from its output. It also does not
    claim that the TTS voice pronounces every word exactly as written.
    """
    locale = case["locale"]
    labels = dict(zip(FIELD_IDS, LABELS[locale], strict=True))
    text = case["spokenText"]
    for field, original in case["expectedSourceQuotes"].items():
        spoken = original
        if field == "examinationNumber":
            spoken = _spoken_digits(original, locale)
        elif field == "patientDateOfBirth":
            year, month, day = original.split("-")
            spoken = ", ".join(_spoken_digits(part, locale) for part in (year, month, day))
        elif field in {"patientHeightCM", "patientWeightKG"}:
            spoken = re.sub(r"(?<!\w)\d{1,3}(?!\w)", lambda match: _spoken_number(match.group(), locale), original)
        elif field == "examinationDescription":
            spoken = _description(original, locale)
        needle = f"{labels[field]}: {original}"
        if needle not in text:
            raise ValueError(f"Source quote is absent from case {case['id']}: {field}")
        text = text.replace(needle, f"{labels[field]}: {spoken}", 1)

    # Semicolons in the first corpus were sometimes spoken literally by macOS
    # Milena. Full stops create natural pauses without changing field order.
    parts = [part.strip().removesuffix(".") for part in text.split("; ")]
    if len(parts) != 8:
        raise ValueError(f"Audio v2 expects all eight fields in case {case['id']}")
    return [part + "." for part in parts]


def make_audio_script(case: dict[str, Any]) -> str:
    """The intended words of one complete dictated form."""
    return " ".join(make_audio_segments(case))
