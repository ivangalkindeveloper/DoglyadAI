from __future__ import annotations

import re


def has_content_outside_evidence(quote: str, excluded: list[str]) -> bool:
    """A copied block of patient metadata cannot become examination findings."""
    remaining = quote
    for evidence in sorted(excluded, key=len, reverse=True):
        remaining = re.sub(re.escape(evidence), "", remaining, flags=re.IGNORECASE)
    return re.search(r"[^\W_]", remaining) is not None
