from __future__ import annotations

import re

from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.configuration.variables import Variables
from app.core.localization.language_code import LanguageCode
from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization


def voice_source_localization_test_support(
    text: str,
) -> USVoiceSourceLocalization:
    configuration = ConfigurationLoader(
        Variables(
            environment="development",
        ).configuration_directory,
    ).load()
    language = (
        LanguageCode.RU
        if re.search(
            r"[\u0400-\u04ff]",
            text,
        )
        else LanguageCode.EN
    )
    return configuration.voice_source_localization(
        language,
    )
