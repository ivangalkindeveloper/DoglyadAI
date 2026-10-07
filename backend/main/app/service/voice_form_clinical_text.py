from __future__ import annotations

import re
from collections import Counter

from app.model.ultrasound.us_voice_field_accuracy import USVoiceFieldAccuracy
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.model.ultrasound.us_voice_field_proposal import USVoiceFieldProposal
from app.service.voice_form_number_evidence import examination_number_markers
from app.service.voice_form_numbers import NUMBER_PHRASE, source_number

_LABEL_FIELDS = {
    "examination number": USVoiceFieldId.EXAMINATION_NUMBER,
    "номер исследования": USVoiceFieldId.EXAMINATION_NUMBER,
    "patient": USVoiceFieldId.PATIENT_NAME,
    "patient name": USVoiceFieldId.PATIENT_NAME,
    "пациент": USVoiceFieldId.PATIENT_NAME,
    "фио": USVoiceFieldId.PATIENT_NAME,
    "gender": USVoiceFieldId.PATIENT_GENDER,
    "пол": USVoiceFieldId.PATIENT_GENDER,
    "date of birth": USVoiceFieldId.PATIENT_DATE_OF_BIRTH,
    "дата рождения": USVoiceFieldId.PATIENT_DATE_OF_BIRTH,
    "height": USVoiceFieldId.PATIENT_HEIGHT_CM,
    "рост": USVoiceFieldId.PATIENT_HEIGHT_CM,
    "weight": USVoiceFieldId.PATIENT_WEIGHT_KG,
    "вес": USVoiceFieldId.PATIENT_WEIGHT_KG,
    "complaints": USVoiceFieldId.PATIENT_COMPLAINTS,
    "жалобы": USVoiceFieldId.PATIENT_COMPLAINTS,
    "examination description": USVoiceFieldId.EXAMINATION_DESCRIPTION,
    "описание исследования": USVoiceFieldId.EXAMINATION_DESCRIPTION,
}
_LABEL_PATTERN = re.compile(
    r"(?<!\w)(?P<label>" + "|".join(re.escape(label) for label in _LABEL_FIELDS) + r")\s*:\s*",
    re.IGNORECASE,
)
_SELF_CORRECTION = re.compile(r",\s*(?:нет|no)\s*,", re.IGNORECASE)
_CLINICAL_FIELDS = {USVoiceFieldId.PATIENT_COMPLAINTS, USVoiceFieldId.EXAMINATION_DESCRIPTION}
_NATURAL_MARKER = re.compile(
    r"\b(?P<description>on\s+ultrasound|ultrasound\s+(?:shows|findings)|на\s+узи|при\s+узи)\b\s*[:,]?\s*"
    r"|\b(?P<complaints>(?:they|he|she|the\s+patient)\s+(?:reports?|complains?\s+of)|"
    r"(?:пациент(?:ка)?\s+)?жалуется\s+на|сообщает)\b\s*:?\s*"
    # Other explicitly attributable fields end a clinical section.
    rf"|\b(?P<other>(?:height|weight|рост|вес|масса\s+тела)\s*"
    rf"(?:(?:is|составляет|равен)\s*)?(?=[:\d]|{NUMBER_PHRASE})|"
    r"(?:and\s+)?weighs?\s+|this\s+is\s+study\s+|study\s+(?:number|id|no\.)\s*|"
    r"(?:это\s+)?исследование\s+номер\s+|today['’]s\s+patient\s+is\s+|"  # noqa: RUF001
    r"сегодня\s+обследуем\s+пациента\s+)",
    re.IGNORECASE,
)
_NUMERIC_CORRECTION = re.compile(
    rf"(?<!\w)(?P<old>{NUMBER_PHRASE})\s*,\s*(?:нет|no)\s*,\s*(?P<new>{NUMBER_PHRASE})"
    r"(?=\s*(?:mm\b|cm\b|ml\b|мм\b|см\b|мл\b|millimet\w*|centimet\w*|millilit\w*|миллимет\w*|сантимет\w*|миллилит\w*))",
    re.IGNORECASE,
)


def _clinical_value(value: str) -> str | None:
    def final_number(match: re.Match[str]) -> str:
        old, new = source_number(match["old"]), source_number(match["new"])
        return match["new"] if old is not None and new is not None else match[0]

    result = _NUMERIC_CORRECTION.sub(final_number, value)
    return None if _SELF_CORRECTION.search(result) else result


def labeled_clinical_text(
    transcript: str, *, description_evidence: str | None = None
) -> dict[USVoiceFieldId, USVoiceFieldProposal]:
    """Preserve clinical sections of explicitly labelled form dictation.

    Natural introductory cues also delimit sections. Keep all clinical sentences;
    only another recognised field cue ends a section. Unsupported corrections and
    repeated sections stay with the model for review.
    """
    markers = list(_LABEL_PATTERN.finditer(transcript))
    explicit = len(markers) >= 2 and not transcript[: markers[0].start()].strip()
    if not explicit:
        markers = sorted(
            [*markers, *_NATURAL_MARKER.finditer(transcript), *examination_number_markers(transcript)],
            key=lambda marker: marker.start(),
        )
    fields = [
        _LABEL_FIELDS[marker["label"].casefold()]
        if "label" in marker.groupdict()
        else USVoiceFieldId.EXAMINATION_DESCRIPTION
        if marker.groupdict().get("description")
        else USVoiceFieldId.PATIENT_COMPLAINTS
        if marker.groupdict().get("complaints")
        else None
        for marker in markers
    ]
    counts = Counter(fields)
    result: dict[USVoiceFieldId, USVoiceFieldProposal] = {}
    description_span: tuple[int, int] | None = None
    if description_evidence and transcript.casefold().count(description_evidence.casefold()) == 1:
        start = transcript.casefold().find(description_evidence.casefold())
        description_span = (start, start + len(description_evidence))
    for index, marker in enumerate(markers):
        field = fields[index]
        if field not in _CLINICAL_FIELDS or counts[field] != 1:
            continue
        end = markers[index + 1].start() if index + 1 < len(markers) else len(transcript)
        if not explicit and field is USVoiceFieldId.PATIENT_COMPLAINTS and index + 1 == len(markers):
            # A literal model quote can bound findings without a spoken heading.
            # An overlapping quote cannot establish this boundary.
            if description_span is not None and description_span[0] >= marker.end():
                end = description_span[0]
            elif description_span is not None and description_span[1] <= marker.start():
                pass
            elif "label" not in marker.groupdict():
                continue
        body = transcript[marker.end() : end].strip()
        # A conjunction introducing the next field is not part of the finding.
        body = re.sub(r"\s+(?:and|и)$", "", body, flags=re.IGNORECASE)
        value = _clinical_value(body)
        if not value:
            continue
        result[field] = USVoiceFieldProposal(
            field_id=field,
            value=value,
            evidence=transcript[marker.start() : end].strip(),
            accuracy=USVoiceFieldAccuracy.FULL if explicit and value == body else USVoiceFieldAccuracy.QUESTIONABLE,
        )
    return result


def clinical_value_is_supported(value: str, evidence: str) -> bool:
    """Allow punctuation/case changes, but no invented clinical words or numbers."""

    def tokens(text: str) -> str:
        return " ".join(re.findall(r"[^\W_]+(?:[.,]\d+)?", text.casefold().replace("ё", "е")))  # noqa: RUF001

    normalized = tokens(value)
    return bool(normalized) and f" {normalized} " in f" {tokens(evidence)} "


def has_content_outside_evidence(quote: str, excluded: list[str]) -> bool:
    """A copied block of patient metadata cannot become examination findings."""
    remaining = quote
    for evidence in sorted(excluded, key=len, reverse=True):
        remaining = re.sub(re.escape(evidence), "", remaining, flags=re.IGNORECASE)
    return re.search(r"[^\W_]", remaining) is not None
