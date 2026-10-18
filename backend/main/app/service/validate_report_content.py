from __future__ import annotations

import re
from decimal import Decimal

from app.core.get_voice_source_localization import get_voice_source_localization
from app.core.language_code import LanguageCode
from app.core.resolve_localized_text import resolve_localized_text
from app.model.ultrasound.us_examination_data import USExaminationData
from app.model.ultrasound.us_examination_report import USExaminationReport
from app.service.clinical_value_is_supported import clinical_value_is_supported


def _measurements(text: str, pattern: str) -> set[tuple[str, Decimal]]:
    result: set[tuple[str, Decimal]] = set()
    for match in re.finditer(pattern, text, re.IGNORECASE):
        value = Decimal(match["value"].replace(",", "."))
        if match["centimeter"]:
            result.add(("length", value * 10))
        elif match["millimeter"]:
            result.add(("length", value))
        else:
            result.add(("volume", value))
    return result


def validate_report_content(
    report: USExaminationReport, examination: USExaminationData, *, language_code: LanguageCode
) -> None:
    """Remove proven misplaced sections and reject altered explicit measurements.

    Literal cross-section copies can be repaired without another generation. Other
    semantic failures are surfaced rather than deleting potentially clinical facts.
    """
    localization = get_voice_source_localization(language_code)
    description = report.description
    for pattern_key, supported in (
        ("reportConclusionSectionPattern", report.conclusion),
        ("reportComplaintsSectionPattern", examination.patientComplaints),
    ):
        pattern = resolve_localized_text(language_code, pattern_key)
        for marker in list(re.finditer(pattern, description, re.IGNORECASE))[::-1]:
            source_value = supported
            lead = marker.groupdict().get("lead")
            if source_value and lead:
                source_value = re.sub(r"^" + re.escape(lead) + r"\s+", "", source_value, flags=re.IGNORECASE)
            # A section can contain multiple sentences. Try sentence boundaries,
            # retaining any following findings such as the bladder volume.
            ends = [marker.end() + end.end() for end in re.finditer(r"[.!?](?=\s|$)|$", description[marker.end() :])]
            end = next(
                (
                    end
                    for end in ends
                    if source_value
                    and clinical_value_is_supported(
                        description[marker.end() : end], source_value, localization=localization, is_complete=True
                    )
                ),
                None,
            )
            if end is None:
                raise ValueError("Unverified section inside report description")
            description = (description[: marker.start()].rstrip() + " " + description[end:].lstrip()).strip()
    if not description:
        raise ValueError("No findings remain in report description")
    pattern = resolve_localized_text(language_code, "reportMeasurementPattern")
    expected = _measurements(examination.examinationDescription, pattern)
    actual = _measurements(description + " " + report.conclusion, pattern)
    if expected and (not expected <= actual or (not examination.photos and not actual <= expected)):
        raise ValueError("Report measurements differ from the examination")
    report.description = description
