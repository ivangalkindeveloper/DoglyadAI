from __future__ import annotations

import app.core.load_configs as _configuration
from app.core.language_code import LanguageCode
from app.model.ultrasound.us_examination_ready_made_template_response import (
    USExaminationReadyMadeTemplateResponse,
)


def resolve_ready_made_templates(language_code: LanguageCode) -> list[USExaminationReadyMadeTemplateResponse]:
    return _configuration._ready_made_templates_response(
        _configuration.ready_made_templates, _configuration._catalog(), language_code
    )
