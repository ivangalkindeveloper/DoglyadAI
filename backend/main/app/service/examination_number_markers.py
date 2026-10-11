from __future__ import annotations

# ruff: noqa: RUF001
import re

# Check the attribution of an identifier, without deriving identifiers from
# anatomical measurements or attempting to repair an unsupported model answer.
_NUMBER_LABEL = re.compile(
    r"\b(?:examination|exam|study)\s+(?:number\b|no\b\.?|id\b|reference\b)"
    r"|\bthis\s+is\s+(?:the\s+)?study\b"
    r"|\bномер\s+исследования\b"
    r"|\bисследование\s+(?:номер\b|№)"
    r"|\b(?:examination|exam|study)\s*[#№]",
    re.IGNORECASE,
)


def examination_number_markers(transcript: str) -> list[re.Match[str]]:
    return list(_NUMBER_LABEL.finditer(transcript))
