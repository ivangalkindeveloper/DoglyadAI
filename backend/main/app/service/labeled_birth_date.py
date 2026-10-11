from __future__ import annotations

import re

from app.service.has_birth_date_cue import _BIRTH_LABEL
from app.service.source_birth_date import source_birth_date


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
