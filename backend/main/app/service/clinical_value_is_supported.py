from __future__ import annotations

import re

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization


def clinical_value_is_supported(
    value: str,
    evidence: str,
    *,
    localization: USVoiceSourceLocalization,
    is_complete: bool = False,
) -> bool:
    """Compare literal clinical tokens, ignoring case and punctuation."""

    def tokens(text: str) -> str:
        return " ".join(re.findall(r"[+-]?\d+(?:[.,]\d+)?|[^\W\d_]+|[<>≤≥±\u00d7/%]+", localization.normalize(text)))

    normalized = tokens(value)
    source = tokens(evidence)
    return bool(normalized) and (normalized == source if is_complete else f" {normalized} " in f" {source} ")
