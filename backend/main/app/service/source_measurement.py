from __future__ import annotations

from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization
from app.service.labeled_measurement import labeled_measurement


def source_measurement(
    evidence: str, field: USVoiceFieldId, *, localization: USVoiceSourceLocalization
) -> float | None:
    """Require a patient-height/weight cue and verify its own number and unit."""
    section = labeled_measurement(evidence, field, localization=localization)
    return section[0] if section is not None else None
