from __future__ import annotations

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization
from app.service.repair_patient_name_evidence import repair_patient_name_evidence


def patient_name_metadata_evidence(
    transcript: str, value: str, *, localization: USVoiceSourceLocalization
) -> str | None:
    quote = repair_patient_name_evidence(transcript, value, localization=localization)
    if quote is None:
        return None
    start = transcript.find(quote)
    introduction = localization.pattern("patientIntroduction").search(transcript[:start])
    return transcript[introduction.start() : start + len(quote)] if introduction is not None else quote
