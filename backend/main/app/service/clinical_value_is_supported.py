from __future__ import annotations

import re


def clinical_value_is_supported(value: str, evidence: str) -> bool:
    """Allow punctuation/case changes, but no invented clinical words or numbers."""

    def tokens(text: str) -> str:
        return " ".join(re.findall(r"[^\W_]+(?:[.,]\d+)?", text.casefold().replace("ё", "е")))  # noqa: RUF001

    normalized = tokens(value)
    return bool(normalized) and f" {normalized} " in f" {tokens(evidence)} "
