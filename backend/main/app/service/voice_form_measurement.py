from __future__ import annotations

import re

from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.service.voice_form_numbers import NUMBER_PHRASE, source_number

_VALUE = rf"(?P<value>{NUMBER_PHRASE}(?:\s+(?:point|запятая)\s+{NUMBER_PHRASE})?)"
_HEIGHT = re.compile(
    rf"\b(?:height|рост)\s*(?:(?:is|of|составляет|равен)\s*)?:?\s*{_VALUE}\s*(?P<unit>\w*)"
    rf"|\b(?P<tall>{NUMBER_PHRASE})\s+(?:centimeters?|centimetres?)\s+tall\b",
    re.IGNORECASE,
)
_WEIGHT = re.compile(
    rf"\b(?:weight|weighs?|вес|весит|масса\s+тела)\s*(?:(?:is|of|составляет)\s*)?:?\s*{_VALUE}\s*(?P<unit>\w*)",
    re.IGNORECASE,
)
_CENTIMETERS = re.compile(r"^(?:cm|см|centimet(?:er|re)s?|сантиметр\w*)$")
_METERS = re.compile(r"^(?:m|м|met(?:er|re)s?|метр\w*)$")
_KILOGRAMS = re.compile(r"^(?:kg|кг|kilograms?|килограмм\w*)$")


def source_measurement(evidence: str, field: USVoiceFieldId) -> float | None:
    """Require a patient-height/weight cue and verify its own number and unit."""
    section = labeled_measurement(evidence, field)
    return section[0] if section is not None else None


def labeled_measurement(transcript: str, field: USVoiceFieldId) -> tuple[float, str] | None:
    match field:
        case USVoiceFieldId.PATIENT_HEIGHT_CM:
            pattern = _HEIGHT
        case USVoiceFieldId.PATIENT_WEIGHT_KG:
            pattern = _WEIGHT
        case _:
            return None
    values: list[tuple[float, str]] = []
    for match in pattern.finditer(transcript):
        clause_end = re.search(r";|\.(?=\s|$)|\n", transcript[match.start() :])
        clause = transcript[match.start() : match.start() + clause_end.start() if clause_end else len(transcript)]
        if re.search(r",\s*(?:no|нет)\s*,|\b(?:or|или|maybe|возможно)\b", clause, re.IGNORECASE):
            return None
        tall = match.groupdict().get("tall")
        value = source_number(tall or match["value"])
        if value is None or value <= 0:
            return None
        unit = "" if tall else (match["unit"] or "").casefold()
        if field is USVoiceFieldId.PATIENT_HEIGHT_CM and _METERS.fullmatch(unit):
            value *= 100
        elif unit and not (_CENTIMETERS if field is USVoiceFieldId.PATIENT_HEIGHT_CM else _KILOGRAMS).fullmatch(unit):
            return None
        values.append((value, match[0]))
    return values[0] if len(values) == 1 else None
