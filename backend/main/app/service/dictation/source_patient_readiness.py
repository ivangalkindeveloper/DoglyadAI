from __future__ import annotations

import re

from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization


def source_patient_readiness(
    transcript: str,
    *,
    localization: USVoiceSourceLocalization,
) -> tuple[str, str] | None:
    """Accept one explicit readiness statement, preserving its negation and quote."""
    matches = [
        (value, match)
        for value, key in (("true", "patientPreparedEvidence"), ("false", "patientUnpreparedEvidence"))
        for match in localization.pattern(
            key,
        ).finditer(
            transcript,
        )
    ]
    if (
        len(
            matches,
        )
        != 1
    ):
        return None
    value, match = matches[0]
    prefix = re.split(
        r"[.;!?\n]",
        transcript[: match.start()],
    )[-1]
    suffix = re.split(
        r"[.;!?\n]",
        transcript[match.end() :],
    )[0]
    if localization.pattern(
        "patientReadinessUncertainty",
    ).search(
        prefix + match[0] + suffix,
    ):
        return None
    if (
        transcript[match.end() :]
        .lstrip()
        .startswith(
            "?",
        )
    ):
        return None
    return value, match[0]
