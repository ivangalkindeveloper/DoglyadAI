from __future__ import annotations

# ruff: noqa: RUF001
import re

_PATIENT_LABEL = re.compile(r"\b(?:patient\s+name|patient|пациент(?:ка|а)?|фио)\b\s*(?:is\s*)?:?\s*$", re.IGNORECASE)


def repair_patient_name_evidence(transcript: str, value: str) -> str | None:
    """Repair a model's paraphrased quote only for a literal, uniquely labelled name."""
    occurrences = list(re.finditer(r"(?<!\w)" + re.escape(value) + r"(?!\w)", transcript, re.IGNORECASE))
    if len(occurrences) != 1:
        return None
    occurrence = occurrences[0]
    prefix = transcript[: occurrence.start()]
    label = _PATIENT_LABEL.search(prefix)
    actual = occurrence[0]
    if label is None or not actual or not actual[0].isupper() or any(character.isdigit() for character in actual):
        return None
    # Do not validate a shortened name when another name word immediately follows.
    suffix = transcript[occurrence.end() :]
    if suffix and suffix[0].isspace() and re.match(r"\s+[^\W\d_]", suffix):
        return None
    return transcript[label.start() : occurrence.end()]
