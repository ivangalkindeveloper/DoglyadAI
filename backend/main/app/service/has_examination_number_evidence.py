from __future__ import annotations

import re

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization
from app.service.has_examination_identifier_evidence import has_examination_identifier_evidence


def has_examination_number_evidence(
    transcript: str, evidence: str, value: str, *, localization: USVoiceSourceLocalization
) -> bool:
    labels_in_quote = list(localization.pattern("numberLabel").finditer(evidence))
    if labels_in_quote:
        return len(labels_in_quote) == 1 and has_examination_identifier_evidence(
            evidence[labels_in_quote[0].end() :], value, localization=localization
        )
    # The model may quote only the identifier. Accept it when its label occurs
    # immediately before the quote; a label elsewhere in the text is no proof.
    occurrence = re.search(re.escape(evidence), transcript, re.IGNORECASE)
    if occurrence is None:
        return False
    prefix = transcript[: occurrence.start()]
    labels = list(localization.pattern("numberLabel").finditer(prefix))
    if not labels:
        return False
    return not prefix[labels[-1].end() :].strip(" \t\n:#№.") and has_examination_identifier_evidence(
        evidence, value, localization=localization
    )
