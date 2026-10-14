from __future__ import annotations

import re

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization


def clinical_value_is_supported(value: str, evidence: str, *, localization: USVoiceSourceLocalization) -> bool:
    """Allow punctuation/case changes, but no invented clinical words or numbers."""

    def tokens(text: str) -> str:
        return " ".join(re.findall(r"[^\W_]+(?:[.,]\d+)?", localization.normalize(text)))

    normalized = tokens(value)
    return bool(normalized) and f" {normalized} " in f" {tokens(evidence)} "
