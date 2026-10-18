from __future__ import annotations

from app.core.language_code import LanguageCode
from app.core.resolve_localized_text import resolve_localized_text


def voice_form_system_prompt(language: LanguageCode) -> str:
    return (
        resolve_localized_text(language, "voiceFormSystemPrompt")
        + " "
        + resolve_localized_text(language, "medicalTermCorrectionPrompt")
    )
