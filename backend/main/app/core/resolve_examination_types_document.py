from __future__ import annotations

import json

import app.core.load_configs as _configuration
from app.core.language_code import LanguageCode


def resolve_examination_types_document(language_code: LanguageCode) -> str:
    response = _configuration._examination_types_response(
        _configuration.examination_type_groups,
        _configuration._catalog(),
        _configuration._contextual_catalog(),
        language_code,
    )
    return json.dumps([item.model_dump(mode="json") for item in response], ensure_ascii=False)
