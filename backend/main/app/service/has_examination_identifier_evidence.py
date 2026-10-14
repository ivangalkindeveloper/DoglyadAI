from __future__ import annotations

import re

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization


def has_examination_identifier_evidence(source: str, value: str, *, localization: USVoiceSourceLocalization) -> bool:
    source = re.split(r";|\.(?=\s|$)|\n", source, maxsplit=1)[0].lstrip(" \t:#№")
    if localization.pattern("uncertainNumber").search(source):
        return False
    literal = re.match(re.escape(value) + r"(?![\w-])", source, re.IGNORECASE)
    if literal is not None:
        # Only a unit immediately following the identifier makes it a measure.
        # A later patient's weight in the same sentence belongs to another field.
        return not localization.pattern("measurementUnit").match(source[literal.end() :].lstrip())
    if localization.pattern("measurementUnit").search(source):
        return False
    words = re.findall(r"\w+", source.casefold())
    return (
        bool(words)
        and all(word in localization.digitWords for word in words)
        and "".join(localization.digitWords[word] for word in words) == value
    )
