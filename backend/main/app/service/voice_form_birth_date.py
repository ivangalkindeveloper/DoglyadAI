from __future__ import annotations

# ruff: noqa: RUF001
import re
from datetime import date

from app.service.voice_form_numbers import NUMBER_PHRASE, source_number, source_year

_MONTHS = dict(
    zip(
        [
            "january",
            "february",
            "march",
            "april",
            "may",
            "june",
            "july",
            "august",
            "september",
            "october",
            "november",
            "december",
            "января",
            "февраля",
            "марта",
            "апреля",
            "мая",
            "июня",
            "июля",
            "августа",
            "сентября",
            "октября",
            "ноября",
            "декабря",
        ],
        [*range(1, 13), *range(1, 13)],
        strict=True,
    )
)
_MONTH = "(?:" + "|".join(_MONTHS) + ")"
_NATURAL = re.compile(
    rf"(?<!\w)(?:the\s+)?(?P<day>{NUMBER_PHRASE})(?:\s+of)?\s+(?P<month>{_MONTH})\s+(?P<year>{NUMBER_PHRASE})(?!\w)"
    rf"|(?<!\w)(?P<month_first>{_MONTH})\s+(?P<day_after>\d{{1,2}})(?:st|nd|rd|th)?\s*,?\s+(?P<year_after>\d{{4}})(?!\d)",
    re.IGNORECASE,
)
_NUMERIC = re.compile(
    r"(?<!\d)(?:(?P<iso>\d{4}-\d{2}-\d{2})|(?P<day>\d{1,2})\.(?P<month>\d{1,2})\.(?P<year>\d{4}))(?!\d)"
)
_BIRTH_LABEL = re.compile(
    r"\b(?:date\s+of\s+birth|birth\s*date|dob|born|дата\s+рождения|родил(?:ся|ась))\b\s*:?\s*", re.IGNORECASE
)
_UNCERTAIN = re.compile(r"\b(?:or|maybe|perhaps|или|возможно|примерно|кажется)\b", re.IGNORECASE)


def source_birth_date(evidence: str) -> str | None:
    """Verify all three date components, refusing incomplete or conflicting dates."""
    if _UNCERTAIN.search(evidence):
        return None
    values: list[str] = []
    for match in _NUMERIC.finditer(evidence):
        try:
            value = (
                date.fromisoformat(match["iso"])
                if match["iso"]
                else date(int(match["year"]), int(match["month"]), int(match["day"]))
            )
        except ValueError:
            return None
        values.append(value.isoformat())
    for match in _NATURAL.finditer(evidence):
        day = source_number(match["day"] or match["day_after"])
        year = source_year(match["year"] or match["year_after"])
        month = _MONTHS[(match["month"] or match["month_first"]).casefold()]
        if day is None or not day.is_integer() or year is None:
            return None
        try:
            values.append(date(year, month, int(day)).isoformat())
        except ValueError:
            return None
    return values[0] if len(values) == 1 else None


def has_birth_date_cue(transcript: str, evidence: str) -> bool:
    if _BIRTH_LABEL.search(evidence) or re.search(r"\bгода\s+рождения\b", evidence, re.IGNORECASE):
        return True
    start = transcript.casefold().find(evidence.casefold())
    labels = list(_BIRTH_LABEL.finditer(transcript[:start]))
    return bool(labels) and not transcript[labels[-1].end() : start].strip(" \t\n:")


def labeled_birth_date(transcript: str) -> tuple[str, str] | None:
    """Recover a missed date only when exactly one explicit birth cue exists."""
    labels = list(_BIRTH_LABEL.finditer(transcript))
    if len(labels) != 1:
        return None
    marker = labels[0]
    # Numeric dd.mm.yyyy dots are not sentence boundaries.
    tail = re.split(r";|\.(?=\s|$)|\n", transcript[marker.end() :], maxsplit=1)[0]
    value = source_birth_date(tail)
    return (value, transcript[marker.start() : marker.end()] + tail) if value is not None else None
