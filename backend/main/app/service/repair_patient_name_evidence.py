from __future__ import annotations

import re

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization


def repair_patient_name_evidence(transcript: str, value: str, *, localization: USVoiceSourceLocalization) -> str | None:
    """Repair a model's paraphrased quote only for a literal, uniquely labelled name."""
    occurrences = list(re.finditer(r"(?<!\w)" + re.escape(value) + r"(?!\w)", transcript, re.IGNORECASE))
    if len(occurrences) != 1:
        return None
    occurrence = occurrences[0]
    prefix = transcript[: occurrence.start()]
    label = localization.pattern("patientLabel").search(prefix)
    actual = occurrence[0]
    if label is None or not actual or not actual[0].isupper() or any(character.isdigit() for character in actual):
        return None
    # Do not validate a shortened name when another name word immediately follows.
    suffix = transcript[occurrence.end() :]
    if suffix and suffix[0].isspace() and re.match(r"\s+[^\W\d_]", suffix):
        return None
    return transcript[label.start() : occurrence.end()]
