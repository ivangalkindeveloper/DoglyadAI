from __future__ import annotations

import re

from app.service.examination_number_markers import _NUMBER_LABEL

_MEASUREMENT_UNIT = re.compile(
    r"\b(?:mm|cm|ml|kg|millimet\w*|centimet\w*|millilit\w*|kilogram\w*|"
    r"мм|см|мл|кг|миллимет\w*|сантимет\w*|миллилит\w*|килограм\w*)\b",
    re.IGNORECASE,
)

_DIGIT_WORDS = dict(
    zip(
        (
            "zero",
            "one",
            "two",
            "three",
            "four",
            "five",
            "six",
            "seven",
            "eight",
            "nine",
            "ноль",
            "один",
            "два",
            "три",
            "четыре",
            "пять",
            "шесть",
            "семь",
            "восемь",
            "девять",
        ),
        "01234567890123456789",
        strict=True,
    )
)


def _matches_identifier(source: str, value: str) -> bool:
    source = re.split(r";|\.(?=\s|$)|\n", source, maxsplit=1)[0].lstrip(" \t:#№")
    if re.search(r",\s*(?:no|нет)\s*,|\b(?:or|или|maybe|возможно)\b", source, re.IGNORECASE):
        return False
    literal = re.match(re.escape(value) + r"(?![\w-])", source, re.IGNORECASE)
    if literal is not None:
        # Only a unit immediately following the identifier makes it a measure.
        # A later patient's weight in the same sentence belongs to another field.
        return not _MEASUREMENT_UNIT.match(source[literal.end() :].lstrip())
    if _MEASUREMENT_UNIT.search(source):
        return False
    words = re.findall(r"\w+", source.casefold())
    return (
        bool(words)
        and all(word in _DIGIT_WORDS for word in words)
        and "".join(_DIGIT_WORDS[word] for word in words) == value
    )


def has_examination_number_evidence(transcript: str, evidence: str, value: str) -> bool:
    labels_in_quote = list(_NUMBER_LABEL.finditer(evidence))
    if labels_in_quote:
        return len(labels_in_quote) == 1 and _matches_identifier(evidence[labels_in_quote[0].end() :], value)
    # The model may quote only the identifier. Accept it when its label occurs
    # immediately before the quote; a label elsewhere in the text is no proof.
    occurrence = re.search(re.escape(evidence), transcript, re.IGNORECASE)
    if occurrence is None:
        return False
    prefix = transcript[: occurrence.start()]
    labels = list(_NUMBER_LABEL.finditer(prefix))
    if not labels:
        return False
    return not prefix[labels[-1].end() :].strip(" \t\n:#№.") and _matches_identifier(evidence, value)
