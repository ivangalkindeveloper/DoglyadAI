from __future__ import annotations

import re
from collections.abc import Mapping

from pydantic import JsonValue

from app.core.language_code import LanguageCode
from app.model.l10n_response import L10nResponse

_PLACEHOLDER = re.compile(r"\{([A-Za-z][A-Za-z0-9]*)\}")
_WORD_MAPS = frozenset(
    {
        "voice.dictation.numbers.digits",
        "voice.speech.literalCharacterReplacements",
        "voice.speech.phoneticCharacterReplacements",
    }
)


def _structure(value: JsonValue, path: str = "voice") -> dict[str, str]:
    """Compare schema, not vocabulary: word maps may have different locale keys."""
    if path in _WORD_MAPS:
        if not isinstance(value, dict) or not all(isinstance(child, str) for child in value.values()):
            raise ValueError(f"Expected a word-to-string map: {path}")
        return {path: "word-map"}
    if isinstance(value, dict):
        result = {path: "object"}
        for key, child in value.items():
            result.update(_structure(child, f"{path}.{key}"))
        return result
    if isinstance(value, list):
        if not all(isinstance(child, str) for child in value):
            raise ValueError(f"Expected localized string array: {path}")
        if path.endswith(".numbers.ones") and len(value) != 20:
            raise ValueError("Spoken numbers must contain 20 ones")
        if path.endswith(".numbers.tens") and len(value) != 10:
            raise ValueError("Spoken numbers must contain 10 tens")
        return {path: "string-array"}
    if isinstance(value, bool):
        return {path: "bool"}
    if isinstance(value, str):
        return {path: "string"}
    raise ValueError(f"Unsupported localization value at {path}")


def validate_application_localizations(catalogs: Mapping[LanguageCode, L10nResponse]) -> None:
    reference = next(iter(catalogs.values()))
    shape = _structure(reference.voice)
    for language, catalog in catalogs.items():
        if catalog.strings.keys() != reference.strings.keys():
            raise ValueError(f"Application localization keys differ: {language.value}")
        for key, text in catalog.strings.items():
            if set(_PLACEHOLDER.findall(text)) != set(_PLACEHOLDER.findall(reference.strings[key])):
                raise ValueError(f"Localization placeholders differ: {key} ({language.value})")
        if _structure(catalog.voice) != shape:
            raise ValueError(f"Voice localization structure differs: {language.value}")
