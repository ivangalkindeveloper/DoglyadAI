from __future__ import annotations

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization


def has_birth_date_cue(transcript: str, evidence: str, *, localization: USVoiceSourceLocalization) -> bool:
    if localization.pattern("birthLabel").search(evidence) or localization.pattern("birthTrailingLabel").search(
        evidence
    ):
        return True
    start = transcript.casefold().find(evidence.casefold())
    labels = list(localization.pattern("birthLabel").finditer(transcript[:start]))
    return bool(labels) and not transcript[labels[-1].end() : start].strip(" \t\n:")
