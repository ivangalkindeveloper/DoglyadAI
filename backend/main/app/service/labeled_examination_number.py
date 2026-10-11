from __future__ import annotations

import re

from app.service.examination_number_markers import _NUMBER_LABEL
from app.service.has_examination_number_evidence import _DIGIT_WORDS, _matches_identifier


def labeled_examination_number(transcript: str) -> tuple[str, str] | None:
    """Copy a unique labelled identifier, including any leading zeroes."""
    labels = list(_NUMBER_LABEL.finditer(transcript))
    if len(labels) != 1:
        return None
    label = labels[0]
    tail = re.split(r";|\.(?=\s|$)|\n", transcript[label.end() :], maxsplit=1)[0].lstrip(" \t:#№")
    words = re.findall(r"\w+", tail.casefold())
    if words and all(word in _DIGIT_WORDS for word in words):
        value = "".join(_DIGIT_WORDS[word] for word in words)
    else:
        literal = re.match(r"[\w-]+", tail)
        if literal is None or not any(character.isdigit() for character in literal[0]):
            return None
        value = literal[0]
    # Use the whole containing clause as evidence, never reconstruct its words.
    end = re.search(r";|\.(?=\s|$)|\n", transcript[label.end() :])
    evidence = transcript[label.start() : label.end() + end.start() if end else len(transcript)]
    return (value, evidence) if _matches_identifier(tail, value) else None
