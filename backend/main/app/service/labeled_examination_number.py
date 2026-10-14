from __future__ import annotations

import re

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization
from app.service.has_examination_identifier_evidence import has_examination_identifier_evidence


def labeled_examination_number(transcript: str, *, localization: USVoiceSourceLocalization) -> tuple[str, str] | None:
    """Copy a unique labelled identifier, including any leading zeroes."""
    labels = list(localization.pattern("numberLabel").finditer(transcript))
    if len(labels) != 1:
        return None
    label = labels[0]
    tail = re.split(r";|\.(?=\s|$)|\n", transcript[label.end() :], maxsplit=1)[0].lstrip(" \t:#№")
    words = re.findall(r"\w+", tail.casefold())
    if words and all(word in localization.digitWords for word in words):
        value = "".join(localization.digitWords[word] for word in words)
    else:
        literal = re.match(r"[\w-]+", tail)
        if literal is None or not any(character.isdigit() for character in literal[0]):
            return None
        value = literal[0]
    # Use the whole containing clause as evidence, never reconstruct its words.
    end = re.search(r";|\.(?=\s|$)|\n", transcript[label.end() :])
    evidence = transcript[label.start() : label.end() + end.start() if end else len(transcript)]
    return (value, evidence) if has_examination_identifier_evidence(tail, value, localization=localization) else None
