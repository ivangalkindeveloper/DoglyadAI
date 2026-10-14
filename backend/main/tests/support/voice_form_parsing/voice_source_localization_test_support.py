from __future__ import annotations

import re

import app.core.load_configs as configuration
from app.core.get_voice_source_localization import get_voice_source_localization
from app.core.language_code import LanguageCode
from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization


def voice_source_localization_test_support(text: str) -> USVoiceSourceLocalization:
    if not configuration._voice_source_localizations:
        configuration.load_configs()
    language = LanguageCode.RU if re.search(r"[\u0400-\u04ff]", text) else LanguageCode.EN
    return get_voice_source_localization(language)
