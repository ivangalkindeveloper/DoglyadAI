from __future__ import annotations

import re

from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization
from app.service.source_number import source_number


def labeled_measurement(
    transcript: str, field: USVoiceFieldId, *, localization: USVoiceSourceLocalization
) -> tuple[float, str] | None:
    match field:
        case USVoiceFieldId.PATIENT_HEIGHT_CM:
            pattern = localization.pattern("height")
        case USVoiceFieldId.PATIENT_WEIGHT_KG:
            pattern = localization.pattern("weight")
        case _:
            return None
    values: list[tuple[float, str]] = []
    for match in pattern.finditer(transcript):
        clause_end = re.search(r";|\.(?=\s|$)|\n", transcript[match.start() :])
        clause = transcript[match.start() : match.start() + clause_end.start() if clause_end else len(transcript)]
        if localization.pattern("uncertainNumber").search(clause):
            return None
        tall = match.groupdict().get("tall")
        value = source_number(tall or match["value"], localization=localization)
        if value is None or value <= 0:
            return None
        unit = "" if tall else (match["unit"] or "").casefold()
        if field is USVoiceFieldId.PATIENT_HEIGHT_CM and localization.pattern("meters").fullmatch(unit):
            value *= 100
        elif unit and not (
            localization.pattern("centimeters")
            if field is USVoiceFieldId.PATIENT_HEIGHT_CM
            else localization.pattern("kilograms")
        ).fullmatch(unit):
            return None
        values.append((value, match[0]))
    return values[0] if len(values) == 1 else None
