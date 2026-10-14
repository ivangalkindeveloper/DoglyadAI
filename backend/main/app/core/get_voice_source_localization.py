from __future__ import annotations

import app.core.load_configs as _configuration
from app.core.language_code import LanguageCode
from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization


def get_voice_source_localization(language_code: LanguageCode) -> USVoiceSourceLocalization:
    if not _configuration._voice_source_localizations:
        raise RuntimeError("Voice source localizations have not been loaded")
    return _configuration._voice_source_localizations[language_code]
