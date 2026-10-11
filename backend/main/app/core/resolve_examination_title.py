from __future__ import annotations

from fastapi import HTTPException

import app.core.load_configs as _configuration
from app.core.language_code import LanguageCode


def resolve_examination_title(type_id: str, language_code: LanguageCode) -> str:
    if type_id not in _configuration.examination_types:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown examination type id: {type_id}",
        )
    return _configuration._catalog().text(language_code, _configuration.examination_types[type_id].titleLocaleKey)
