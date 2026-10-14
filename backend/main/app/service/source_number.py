from __future__ import annotations

import re

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization


def _group(words: list[str], *, localization: USVoiceSourceLocalization) -> int | None:
    if not words:
        return 0
    if localization.hundredWord is not None and localization.hundredWord in words:
        if words.count(localization.hundredWord) != 1 or words.index(localization.hundredWord) != 1:
            return None
        leading = localization.numbers.get(words[0], -1)
        tail = _group(words[2:], localization=localization)
        return leading * 100 + tail if 1 <= leading <= 9 and tail is not None and tail < 100 else None
    values = [localization.numbers.get(word, -1) for word in words]
    if any(value < 0 for value in values) or len(values) > 3:
        return None
    if len(values) == 1:
        return values[0]
    # hundreds + tens + units, or hundreds + teens/units, or tens + units.
    if values[0] >= 100:
        if values[0] % 100 or values[0] > 900:
            return None
        tail = _group(words[1:], localization=localization)
        return values[0] + tail if tail is not None and 0 < tail < 100 else None
    if len(values) == 2 and 20 <= values[0] <= 90 and values[0] % 10 == 0 and 1 <= values[1] <= 9:
        return sum(values)
    return None


def source_number(text: str, *, localization: USVoiceSourceLocalization) -> float | None:
    """Parse a complete RU/EN cardinal/ordinal phrase; never skip unknown text."""
    text = localization.normalize(text).strip()
    words_map = localization.numbers
    if re.fullmatch(r"\d+(?:[.,]\d+)?", text):
        return float(text.replace(",", "."))
    decimal = localization.pattern("decimalSeparator").split(text)
    if len(decimal) == 2:
        whole = source_number(decimal[0], localization=localization)
        digits = [words_map.get(word, -1) for word in decimal[1].split()]
        if whole is None or not digits or any(not 0 <= digit <= 9 for digit in digits):
            return None
        return whole + float("0." + "".join(map(str, digits)))
    if len(decimal) != 1:
        return None
    words = [word for word in re.split(r"[\s-]+", text) if not localization.pattern("numberJoinerWord").fullmatch(word)]
    # Canonicalise the two spellings of the Russian vowel, preserving unknown words.
    canonical = {localization.normalize(key): key for key in localization.numbers}
    words = [canonical.get(word, word) for word in words]
    scales = [index for index, word in enumerate(words) if localization.scaleWords.get(word) == 1000]
    if scales:
        if len(scales) != 1:
            return None
        index = scales[0]
        leading = _group(words[:index], localization=localization) if index else 1
        tail = _group(words[index + 1 :], localization=localization)
        return (
            float(leading * 1000 + tail)
            if leading is not None and 1 <= leading <= 9 and tail is not None and tail < 1000
            else None
        )
    value = _group(words, localization=localization)
    return float(value) if value is not None else None
