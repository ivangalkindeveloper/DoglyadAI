from __future__ import annotations

import regex

from app.error.text_too_long_error import TextTooLongError


class TextLengthValidator:
    """Count extended grapheme clusters, as Swift String.count does, without copying input."""

    @staticmethod
    def is_within_limit(value: str, maximum: int) -> bool:
        return all(index < maximum for index, _ in enumerate(regex.finditer(r"\X", value)))

    @classmethod
    def validate(cls, value: str | None, maximum: int, location: list[str | int]) -> None:
        if value is not None and not cls.is_within_limit(value, maximum):
            raise TextTooLongError(location)
