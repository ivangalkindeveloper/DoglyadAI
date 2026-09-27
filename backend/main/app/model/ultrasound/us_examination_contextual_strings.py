from __future__ import annotations

from pydantic import RootModel, model_validator

from app.core.language_code import LanguageCode


class USExaminationContextualStrings(RootModel[dict[LanguageCode, dict[str, list[str]]]]):
    @model_validator(mode="after")
    def validate_catalog(self) -> USExaminationContextualStrings:
        if set(self.root) != set(LanguageCode):
            raise ValueError("Every supported language must have contextual strings")

        en = self.root[LanguageCode.EN]
        ru = self.root[LanguageCode.RU]
        if en.keys() != ru.keys():
            missing_en = sorted(ru.keys() - en.keys())
            missing_ru = sorted(en.keys() - ru.keys())
            raise ValueError(
                f"Contextual string type ids differ: missing in {LanguageCode.EN.value}={missing_en}, "
                f"missing in {LanguageCode.RU.value}={missing_ru}"
            )

        for language, types in self.root.items():
            for type_id, phrases in types.items():
                if not 1 <= len(phrases) <= 100:
                    raise ValueError(f"Expected 1-100 contextual strings: {type_id} ({language})")
                normalized = [phrase.strip().casefold() for phrase in phrases]
                if any(not phrase for phrase in normalized) or len(normalized) != len(set(normalized)):
                    raise ValueError(f"Empty or duplicate contextual strings: {type_id} ({language})")
        return self

    def validate_type_ids(self, type_ids: set[str]) -> None:
        actual = set(self.root[LanguageCode.EN])
        if actual != type_ids:
            raise ValueError(
                f"Contextual strings do not match examination types: missing={sorted(type_ids - actual)}, "
                f"unknown={sorted(actual - type_ids)}"
            )

    def for_type(self, language: LanguageCode, type_id: str) -> list[str]:
        return self.root[language][type_id]
