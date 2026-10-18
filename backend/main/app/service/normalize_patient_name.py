from __future__ import annotations

import re


def normalize_patient_name(value: str) -> str:
    """Change only case; retain mixed-case spellings, letters and separators."""
    return re.sub(
        r"[^\W\d_]+",
        lambda match: match[0].capitalize() if match[0].islower() or match[0].isupper() else match[0],
        value,
    )
