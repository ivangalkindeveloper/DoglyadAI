from __future__ import annotations

from datetime import date

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization
from app.service.source_number import source_number
from app.service.source_year import source_year


def source_birth_date(evidence: str, *, localization: USVoiceSourceLocalization) -> str | None:
    """Verify all three date components, refusing incomplete or conflicting dates."""
    if localization.pattern("uncertainDate").search(evidence):
        return None
    values: list[str] = []
    for match in localization.pattern("groupedNumericBirthDate").finditer(evidence):
        prefix, suffix = evidence[: match.start()].rstrip(), evidence[match.end() :].lstrip()
        if (prefix and prefix[-1].isdigit()) or (suffix and suffix[0].isdigit()):
            return None
        try:
            value = date(
                int(match["year"]),
                int("".join(match["month"].split())),
                int("".join(match["day"].split())),
            )
        except ValueError:
            return None
        values.append(value.isoformat())
    for match in localization.pattern("numericBirthDate").finditer(evidence):
        try:
            value = (
                date.fromisoformat(match["iso"])
                if match["iso"]
                else date(int(match["year"]), int(match["month"]), int(match["day"]))
            )
        except ValueError:
            return None
        values.append(value.isoformat())
    for match in localization.pattern("naturalBirthDate").finditer(evidence):
        day = source_number(match["day"] or match.groupdict().get("day_after", ""), localization=localization)
        year = source_year(match["year"] or match.groupdict().get("year_after", ""), localization=localization)
        month = localization.monthWords[(match["month"] or match.groupdict().get("month_first", "")).casefold()]
        if day is None or not day.is_integer() or year is None:
            return None
        try:
            values.append(date(year, month, int(day)).isoformat())
        except ValueError:
            return None
    return values[0] if len(values) == 1 else None
