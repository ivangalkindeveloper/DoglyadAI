from __future__ import annotations

import re

from app.service.labeled_patient_gender import _FETAL, _GENDERS, _WORD

_VALUE = re.compile(rf"\b{_WORD}\b", re.IGNORECASE)


def gender_from_evidence(evidence: str) -> str | None:
    """A patient's sex cannot be inferred from their name or anatomy."""
    if _FETAL.search(evidence):
        return None
    words = list(_VALUE.finditer(evidence))
    return _GENDERS[words[0][0].casefold()] if len(words) == 1 else None
