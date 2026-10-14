from __future__ import annotations

import re
from collections import Counter

from app.model.ultrasound.us_voice_field_accuracy import USVoiceFieldAccuracy
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.model.ultrasound.us_voice_field_proposal import USVoiceFieldProposal
from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization
from app.service.examination_number_markers import examination_number_markers
from app.service.source_number import source_number

_CLINICAL_FIELDS = {USVoiceFieldId.PATIENT_COMPLAINTS, USVoiceFieldId.EXAMINATION_DESCRIPTION}


def _clinical_value(value: str, *, localization: USVoiceSourceLocalization) -> str | None:
    def final_number(match: re.Match[str]) -> str:
        old, new = (
            source_number(match["old"], localization=localization),
            source_number(match["new"], localization=localization),
        )
        return match["new"] if old is not None and new is not None else match[0]

    result = localization.pattern("numericCorrection").sub(final_number, value)
    return None if localization.pattern("selfCorrection").search(result) else result


def labeled_clinical_text(
    transcript: str, *, description_evidence: str | None = None, localization: USVoiceSourceLocalization
) -> dict[USVoiceFieldId, USVoiceFieldProposal]:
    """Preserve clinical sections of explicitly labelled form dictation.

    Natural introductory cues also delimit sections. Keep all clinical sentences;
    only another recognised field cue ends a section. Unsupported corrections and
    repeated sections stay with the model for review.
    """
    label_pattern = re.compile(
        r"(?<!\w)(?P<label>" + "|".join(re.escape(label) for label in localization.labelFields) + r")\s*:\s*",
        re.IGNORECASE,
    )
    markers = list(label_pattern.finditer(transcript))
    is_explicit = len(markers) >= 2 and not transcript[: markers[0].start()].strip()
    if not is_explicit:
        markers = sorted(
            [
                *markers,
                *localization.pattern("clinicalNaturalMarker").finditer(transcript),
                *examination_number_markers(transcript, localization=localization),
            ],
            key=lambda marker: marker.start(),
        )
    fields = [
        localization.labelFields[marker["label"].casefold()]
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
        if not is_explicit and field is USVoiceFieldId.PATIENT_COMPLAINTS and index + 1 == len(markers):
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
        body = localization.pattern("clinicalConjunctionSuffix").sub("", body)
        value = _clinical_value(body, localization=localization)
        if not value:
            continue
        result[field] = USVoiceFieldProposal(
            fieldId=field,
            value=value,
            evidence=transcript[marker.start() : end].strip(),
            accuracy=USVoiceFieldAccuracy.FULL if is_explicit and value == body else USVoiceFieldAccuracy.QUESTIONABLE,
        )
    return result
