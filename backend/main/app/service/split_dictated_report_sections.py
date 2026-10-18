from __future__ import annotations

import re

from app.model.ultrasound.us_dictated_report_sections import USDictatedReportSections


def split_dictated_report_sections(text: str, *, conclusion_pattern: str) -> USDictatedReportSections:
    """Separate one explicit heading; preserve ambiguous or repeated sections intact."""
    markers = list(re.finditer(conclusion_pattern, text, re.IGNORECASE))
    if len(markers) != 1:
        return USDictatedReportSections(description=text)
    marker = markers[0]
    conclusion = text[marker.end() :].strip()
    if not conclusion:
        return USDictatedReportSections(description=text)
    return USDictatedReportSections(description=text[: marker.start()].strip(), conclusion=conclusion)
