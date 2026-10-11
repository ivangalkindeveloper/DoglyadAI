from __future__ import annotations

from pydantic import RootModel, model_validator

from app.core.language_code import LanguageCode


class L10n(RootModel[dict[LanguageCode, dict[str, str]]]):
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

    def text(self, language: LanguageCode, key: str) -> str:
        values = self.root[language]
        if key not in values:
            raise ValueError(f"Missing localization key: {key}")
        value = values[key]
        if not value.strip():
            raise ValueError(f"Expected non-empty localized text: {key} ({language})")
        return value
