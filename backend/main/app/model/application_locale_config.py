from __future__ import annotations

from typing import Self

from pydantic import BaseModel, ConfigDict, model_validator

from app.core.language_code import LanguageCode


class ApplicationLocaleConfig(BaseModel):
    model_config = ConfigDict(extra="forbid")

    defaultCode: LanguageCode
    codes: list[LanguageCode]

    @model_validator(mode="after")
    def validate_codes(self) -> Self:
        if not self.codes:
            raise ValueError("Application locale codes must not be empty")
        if len(self.codes) != len(set(self.codes)):
            raise ValueError("Application locale codes must be unique")
        if self.defaultCode not in self.codes:
            raise ValueError("Application locale defaultCode must be included in codes")
        return self
