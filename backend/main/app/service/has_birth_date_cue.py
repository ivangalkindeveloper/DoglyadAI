from __future__ import annotations

# ruff: noqa: RUF001
import re

_BIRTH_LABEL = re.compile(
    r"\b(?:date\s+of\s+birth|birth\s*date|dob|born|дата\s+рождения|родил(?:ся|ась))\b\s*:?\s*", re.IGNORECASE
)


def has_birth_date_cue(transcript: str, evidence: str) -> bool:
    if _BIRTH_LABEL.search(evidence) or re.search(r"\bгода\s+рождения\b", evidence, re.IGNORECASE):
        return True
    start = transcript.casefold().find(evidence.casefold())
    labels = list(_BIRTH_LABEL.finditer(transcript[:start]))
    return bool(labels) and not transcript[labels[-1].end() : start].strip(" \t\n:")
