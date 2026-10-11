from __future__ import annotations

import app.core.load_configs as _configuration
from app.core.language_code import LanguageCode


def resolve_localized_text(language_code: LanguageCode, key: str) -> str:
    return _configuration._catalog().text(language_code, key)
