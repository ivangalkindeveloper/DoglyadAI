from __future__ import annotations

import re

from evaluation.voice.asr import words
from evaluation.voice.audio_script_v2 import DIGIT_WORDS
from evaluation.voice.common import _number_words

UNIT_ALIASES = {
    "en": {
        "cm": {"centimeter", "centimeters", "centimetre", "centimetres"},
        "kg": {"kilogram", "kilograms"},
        "mm": {"millimeter", "millimeters", "millimetre", "millimetres"},
        "ml": {"milliliter", "milliliters", "millilitre", "millilitres"},
    },
    "ru": {
        "см": {"сантиметр", "сантиметра", "сантиметров", "сантиметры"},
        "кг": {"килограмм", "килограмма", "килограммов", "килограммы"},
        "мм": {"миллиметр", "миллиметра", "миллиметров", "миллиметры"},
        "мл": {"миллилитр", "миллилитра", "миллилитров", "миллилитры"},
    },
}

SPEED_UNIT_PATTERNS = {
    "en": r"\b(?:cm\s*/\s*s|cm\s+per\s+second|centimet(?:er|re)s?\s+per\s+second)\b",
    "ru": r"\b(?:см\s*/\s*с|см\s+в\s+секунду|сантиметр(?:ов|а|ы)?\s+в\s+секунду)\b",
}


def _normalize_speed_unit(text: str, locale: str) -> str:
    return re.sub(SPEED_UNIT_PATTERNS[locale], "cmspeedunit", text, flags=re.IGNORECASE)


def _asr_tokens(text: str) -> list[str]:
    tokens = words(text)
    result: list[str] = []
    for token in tokens:
        joined = re.fullmatch(r"(\d+)([a-zа-яё]+)", token)
        if joined:
            result.extend(joined.groups())
        else:
            result.append(token)
    return result


def _number_phrases(token: str, locale: str) -> list[list[str]]:
    if not token.isascii() or not token.isdigit():
        return []
    digit_words = [DIGIT_WORDS[locale][int(digit)] for digit in token]
    phrases = [digit_words]
    number = int(token)
    if not token.startswith("0") and 1 <= number <= 199:
        cardinal = _number_words(number, locale).split()
        if cardinal != digit_words:
            phrases.append(cardinal)
    return phrases


def _same_word(expected: str, actual: str, locale: str) -> bool:
    if expected == actual:
        return True
    return any(
        expected in {abbreviation, *forms} and actual in {abbreviation, *forms}
        for abbreviation, forms in UNIT_ALIASES[locale].items()
    )


def spoken_normalized_wer(reference: str, transcript: str, locale: str) -> float:
    """WER after accepting numeric display forms and unit abbreviations.

    This keeps wrong numbers, missing negations, sides and other words as errors.
    It is a normalization of *written ASR output*, not a human transcript of TTS.
    """
    if locale not in DIGIT_WORDS:
        raise ValueError(f"Unsupported locale: {locale}")
    expected = words(_normalize_speed_unit(reference, locale))
    actual = _asr_tokens(_normalize_speed_unit(transcript, locale))
    if not expected:
        return 0.0 if not actual else 1.0
    rows, columns = len(expected), len(actual)
    distance = [[rows + columns + 1] * (columns + 1) for _ in range(rows + 1)]
    distance[0][0] = 0
    for i in range(rows + 1):
        for j in range(columns + 1):
            current = distance[i][j]
            if i < rows:
                distance[i + 1][j] = min(distance[i + 1][j], current + 1)
            if j >= columns:
                continue
            distance[i][j + 1] = min(distance[i][j + 1], current + 1)
            if i < rows:
                cost = 0 if _same_word(expected[i], actual[j], locale) else 1
                distance[i + 1][j + 1] = min(distance[i + 1][j + 1], current + cost)
            for phrase in _number_phrases(actual[j], locale):
                end = i + len(phrase)
                if end <= rows and expected[i:end] == phrase:
                    distance[end][j + 1] = min(distance[end][j + 1], current)
    return distance[rows][columns] / rows
