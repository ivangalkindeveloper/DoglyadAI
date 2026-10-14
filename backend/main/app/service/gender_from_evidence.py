from __future__ import annotations

import re

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization


def gender_from_evidence(evidence: str, *, localization: USVoiceSourceLocalization) -> str | None:
    """A patient's sex cannot be inferred from their name or anatomy."""
    if localization.pattern("fetalCue").search(evidence):
        return None
    word_pattern = re.compile(
        r"\b(?:" + "|".join(re.escape(word) for word in localization.genderWords) + r")\b", re.IGNORECASE
    )
    words = list(word_pattern.finditer(evidence))
    return localization.genderWords[words[0][0].casefold()] if len(words) == 1 else None
