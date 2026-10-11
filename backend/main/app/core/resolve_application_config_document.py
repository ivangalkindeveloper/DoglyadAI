from __future__ import annotations

import json

import app.core.load_configs as _configuration
from app.core.language_code import LanguageCode


def resolve_application_config_document(language_code: LanguageCode) -> str:
    return json.dumps(
        _configuration._application_response(
            _configuration._application_config, _configuration._catalog(), language_code
        ),
        ensure_ascii=False,
    )
