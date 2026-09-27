from __future__ import annotations

from app.core.language_code import LanguageCode

SUPPORTED_LANGUAGES = tuple(LanguageCode)
DEFAULT_LANGUAGE = LanguageCode.EN


def resolve_language(accept_language: str | None) -> LanguageCode:
    """Choose the highest-priority supported language from Accept-Language."""
    if not accept_language:
        return DEFAULT_LANGUAGE

    choices: list[tuple[float, int, LanguageCode]] = []
    for index, item in enumerate(accept_language.split(",")):
        tag, *parameters = item.strip().split(";")
        language_tag = tag.strip().replace("_", "-").split("-")[0].lower()
        try:
            language = LanguageCode(language_tag)
        except ValueError:
            continue
        quality = 1.0
        for parameter in parameters:
            key, separator, value = parameter.strip().partition("=")
            if key.lower() == "q":
                try:
                    quality = float(value) if separator else 0.0
                except ValueError:
                    quality = 0.0
                break
        if 0 < quality <= 1:
            choices.append((-quality, index, language))

    return min(choices)[2] if choices else DEFAULT_LANGUAGE
