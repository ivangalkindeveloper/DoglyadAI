from __future__ import annotations

# ruff: noqa: RUF001
import re

# Check the attribution of an identifier, without deriving identifiers from
# anatomical measurements or attempting to repair an unsupported model answer.
_NUMBER_LABEL = re.compile(
    r"\b(?:examination|exam|study)\s+(?:number\b|no\b\.?|id\b|reference\b)"
    r"|\bthis\s+is\s+(?:the\s+)?study\b"
    r"|\bномер\s+исследования\b"
    r"|\bисследование\s+(?:номер\b|№)"
    r"|\b(?:examination|exam|study)\s*[#№]",
    re.IGNORECASE,
)
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


def examination_number_markers(transcript: str) -> list[re.Match[str]]:
    return list(_NUMBER_LABEL.finditer(transcript))


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
