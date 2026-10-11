from __future__ import annotations

import json

import app.core.load_configs as _configuration
from app.core.language_code import LanguageCode


def resolve_neural_models_document(language_code: LanguageCode) -> str:
    response = _configuration._neural_models_response(
        list(_configuration.neural_models.values()), _configuration._catalog(), language_code
    )
    return json.dumps([item.model_dump(mode="json") for item in response], ensure_ascii=False)
