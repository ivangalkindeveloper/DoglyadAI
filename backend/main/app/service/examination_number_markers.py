from __future__ import annotations

import re

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization

# Check the attribution of an identifier, without deriving identifiers from
# anatomical measurements or attempting to repair an unsupported model answer.


def examination_number_markers(transcript: str, *, localization: USVoiceSourceLocalization) -> list[re.Match[str]]:
    return list(localization.pattern("numberLabel").finditer(transcript))
