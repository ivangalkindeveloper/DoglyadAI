from __future__ import annotations

from pydantic import RootModel, model_validator

from app.core.language_code import LanguageCode


class L10n(RootModel[dict[LanguageCode, dict[str, str | list[str]]]]):
    @model_validator(mode="after")
    def matching_keys(self) -> L10n:
        if set(self.root) != set(LanguageCode):
            raise ValueError("Every supported language must have a localization section")
        en = self.root[LanguageCode.EN]
        ru = self.root[LanguageCode.RU]
        if en.keys() != ru.keys():
            raise ValueError(
                f"Localization keys differ: missing in {LanguageCode.EN.value}={sorted(ru.keys() - en.keys())}, "
                f"missing in {LanguageCode.RU.value}={sorted(en.keys() - ru.keys())}"
            )
        return self

    def _value(self, language: LanguageCode, key: str) -> str | list[str]:
        values = self.root[language]
        if key not in values:
            raise ValueError(f"Missing localization key: {key}")
        return values[key]

    def text(self, language: LanguageCode, key: str) -> str:
        value = self._value(language, key)
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"Expected non-empty localized text: {key} ({language})")
        return value

    def contextual_strings(self, language: LanguageCode, key: str) -> list[str]:
        value = self._value(language, key)
        if not isinstance(value, list) or not 1 <= len(value) <= 100:
            raise ValueError(f"Expected 1-100 contextual strings: {key} ({language})")
        normalized = [text.strip().casefold() for text in value]
        if any(not text for text in normalized) or len(normalized) != len(set(normalized)):
            raise ValueError(f"Empty or duplicate contextual strings: {key} ({language})")
        return value
