from __future__ import annotations

import app.core.load_configs as _configuration
from app.model.ultrasound.us_voice_form_parsing_config import USVoiceFormParsingConfig


def get_voice_parsing_config() -> USVoiceFormParsingConfig:
    if _configuration._voice_parsing_config is None:
        raise RuntimeError("Voice parsing config has not been loaded")
    return _configuration._voice_parsing_config
