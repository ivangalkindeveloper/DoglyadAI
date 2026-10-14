from __future__ import annotations

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization
from app.service.source_number import source_number


def source_year(text: str, *, localization: USVoiceSourceLocalization) -> int | None:
    words = text.casefold().replace("-", " ").split()
    if (
        words
        and words[0] in localization.centuryWords
        and len(words) > 1
        and localization.scaleWords.get(words[1]) != 1000
    ):
        tail = source_number(" ".join(words[1:]).removeprefix(localization.yearZeroPrefix), localization=localization)
        value = localization.centuryWords[words[0]] * 100 + tail if tail is not None and 0 <= tail < 100 else None
    else:
        value = source_number(text, localization=localization)
    return int(value) if value is not None and value.is_integer() and 1800 <= value <= 2099 else None
