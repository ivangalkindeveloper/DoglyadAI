from __future__ import annotations

import re
from typing import Self

from pydantic import BaseModel, ConfigDict, PrivateAttr, model_validator

from app.model.ultrasound.us_voice_field_id import USVoiceFieldId


class USVoiceSourceLocalization(BaseModel):
    """Server evidence rules composed with the client catalog's shared vocabulary."""

    model_config = ConfigDict(extra="forbid")

    additionalNumberWords: dict[str, int]
    centuryWords: dict[str, int]
    genderWords: dict[str, str]
    hundredWord: str | None
    labelFields: dict[str, USVoiceFieldId]
    monthWords: dict[str, int]
    patterns: dict[str, str]
    scaleWords: dict[str, int]
    yearZeroPrefix: str
    numberWords: dict[str, int]
    digitWords: dict[str, str]
    characterReplacements: dict[str, str]
    _compiled_patterns: dict[str, re.Pattern[str]] = PrivateAttr(default_factory=dict)
    _number_phrase: str = PrivateAttr(default="")

    @model_validator(mode="after")
    def compile_patterns(self) -> Self:
        required = {
            "birthLabel",
            "birthTrailingLabel",
            "centimeters",
            "clinicalConjunctionSuffix",
            "clinicalNaturalMarker",
            "decimalSeparator",
            "fetalCue",
            "genderLabel",
            "height",
            "kilograms",
            "measurementUnit",
            "meters",
            "naturalBirthDate",
            "numberJoiner",
            "numberJoinerWord",
            "numberLabel",
            "numericBirthDate",
            "numericCorrection",
            "patientIntroduction",
            "patientLabel",
            "selfCorrection",
            "uncertainDate",
            "uncertainNumber",
            "weight",
        }
        if set(self.patterns) != required:
            raise ValueError("Voice source localization must define every parsing pattern")
        if not self.numberWords or not self.digitWords or not self.labelFields or not self.genderWords:
            raise ValueError("Voice source vocabularies must not be empty")
        if set(self.monthWords.values()) != set(range(1, 13)):
            raise ValueError("Voice source localization must define twelve months")
        if not set(self.genderWords.values()) <= {"male", "female"}:
            raise ValueError("Invalid gender vocabulary")
        words = {**self.numberWords, **self.additionalNumberWords, **self.scaleWords}
        token = (
            "(?:" + "|".join(re.escape(word) for word in sorted(words, key=len, reverse=True)) + r"|\d+(?:[.,]\d+)?)"
        )
        # Patterns match original text; numeric parsing canonicalizes characters separately.
        for original, replacement in self.characterReplacements.items():
            if len(original) == len(replacement) == 1:
                token = token.replace(re.escape(original), "[" + re.escape(original + replacement) + "]")
        self._number_phrase = token + r"(?:[\s-]+" + self.patterns["numberJoiner"] + token + r")*"
        substitutions = {
            "{numberPhrase}": self._number_phrase,
            "{genderWord}": "(?:" + "|".join(re.escape(word) for word in self.genderWords) + ")",
            "{monthWord}": "(?:" + "|".join(re.escape(word) for word in self.monthWords) + ")",
        }
        try:
            for key, template in self.patterns.items():
                for placeholder, value in substitutions.items():
                    template = template.replace(placeholder, value)
                self._compiled_patterns[key] = re.compile(template, re.IGNORECASE)
        except re.error as error:
            raise ValueError("Invalid voice source parsing pattern") from error
        return self

    @property
    def number_phrase(self) -> str:
        return self._number_phrase

    @property
    def numbers(self) -> dict[str, int]:
        return {self.normalize(key): value for key, value in {**self.numberWords, **self.additionalNumberWords}.items()}

    def normalize(self, text: str) -> str:
        text = text.casefold()
        for original, replacement in self.characterReplacements.items():
            text = text.replace(original, replacement)
        return text

    def pattern(self, key: str) -> re.Pattern[str]:
        return self._compiled_patterns[key]
