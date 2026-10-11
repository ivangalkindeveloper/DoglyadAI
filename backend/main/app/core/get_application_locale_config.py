from __future__ import annotations

import app.core.load_configs as _configuration
from app.model.application_locale_config import ApplicationLocaleConfig


def get_application_locale_config() -> ApplicationLocaleConfig:
    if _configuration._locale_config is None:
        raise RuntimeError("Application locale config has not been loaded")
    return _configuration._locale_config
