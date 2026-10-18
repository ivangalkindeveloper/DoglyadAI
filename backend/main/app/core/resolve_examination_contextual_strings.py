from __future__ import annotations

import app.core.load_configs as _configuration
from app.core.language_code import LanguageCode
from app.core.resolve_examination_title import resolve_examination_title


def resolve_examination_contextual_strings(type_id: str, language_code: LanguageCode) -> list[str]:
    resolve_examination_title(type_id, language_code)
    return _configuration._contextual_catalog().for_type(language_code, type_id)
