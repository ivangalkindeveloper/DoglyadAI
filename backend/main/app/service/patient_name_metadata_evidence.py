from __future__ import annotations

import re

from app.service.repair_patient_name_evidence import repair_patient_name_evidence

_INTRODUCTION = re.compile(r"(?:сегодня\s+обследуем|today['’]s)\s*$", re.IGNORECASE)  # noqa: RUF001


def patient_name_metadata_evidence(transcript: str, value: str) -> str | None:
    quote = repair_patient_name_evidence(transcript, value)
    if quote is None:
        return None
    start = transcript.find(quote)
    introduction = _INTRODUCTION.search(transcript[:start])
    return transcript[introduction.start() : start + len(quote)] if introduction is not None else quote
