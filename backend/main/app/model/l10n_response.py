from __future__ import annotations

from pydantic import BaseModel, JsonValue, model_validator

from app.core.language_code import LanguageCode


class L10nResponse(BaseModel):
    code: LanguageCode
    strings: dict[str, str]
    voice: dict[str, JsonValue]

    @model_validator(mode="after")
    def complete_catalog(self) -> L10nResponse:
        if not self.strings or any(not key or not text.strip() for key, text in self.strings.items()):
            raise ValueError("Application localization must contain non-empty keys and translations")
        if self.voice.get("code") != self.code.value:
            raise ValueError("Voice catalog language must match the application catalog")
        if not isinstance(self.voice.get("dictation"), dict) or not isinstance(self.voice.get("speech"), dict):
            raise ValueError("Voice localization must include dictation and speech catalogs")
        return self
