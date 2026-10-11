from __future__ import annotations

import app.core.load_configs as _configuration
from app.core.language_code import LanguageCode


def resolve_l10n_document(language_code: LanguageCode) -> str:
    if not _configuration._application_localizations:
        raise RuntimeError("Application localizations have not been loaded")
    return _configuration._application_localizations[language_code].model_dump_json()
