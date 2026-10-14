from __future__ import annotations

import re

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization


def labeled_patient_gender(transcript: str, *, localization: USVoiceSourceLocalization) -> tuple[str, str] | None:
    sections: list[tuple[str, str]] = []
    for marker in localization.pattern("genderLabel").finditer(transcript):
        prefix = re.split(r"[.;\n]", transcript[: marker.start()])[-1]
        if localization.pattern("fetalCue").search(prefix):
            continue
        sections.append((localization.genderWords[marker["gender"].casefold()], marker[0]))
    return sections[0] if len(sections) == 1 else None
