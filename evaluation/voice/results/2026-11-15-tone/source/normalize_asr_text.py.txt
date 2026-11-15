from __future__ import annotations

import re
from datetime import date
from functools import lru_cache

from evaluation.voice.scoring.normalize_evaluation_text import normalize_evaluation_text


@lru_cache(maxsize=32768)
def normalize_asr_text(text: str, locale: str) -> tuple[str, ...]:
    """Normalize ASR display conventions, separately from field correctness.

    A spaced typographic dash after a nonnumeric word is report punctuation.
    Numeric ranges, ASCII/Unicode minus signs and adjacent signed numbers stay
    significant. This phonetic metric must never certify clinical equivalence.
    """
    text = text.casefold()

    def separator(match: re.Match[str]) -> str:
        word = match[1]
        tokens = normalize_evaluation_text(word, locale)
        return match[0] if any(token.isdigit() for token in tokens) else word + " "

    text = re.sub(r"\b([^\W\d_]+)\s+[–—]\s+", separator, text)
    # Label separators before categorical fields cannot be numeric signs.
    text = re.sub(
        r"\b(пол|пациент|пациентка|жалобы|описание исследования|gender|patient|complaints|examination description)\s+-\s+",
        r"\1 ",
        text,
    )

    def birth_digits(match: re.Match[str]) -> str:
        context = text[max(0, match.start() - 40) : match.end() + 40]
        if not re.search(r"\b(?:birth|born|рождения|родился|родилась)\b", context):
            return match[0]
        digits = re.sub(r"\D", "", match[0])
        parts = re.split(r"\s*-\s*", match[0])
        if len(parts) == 3 and len(parts[0]) == 4 and all(1 <= len(part) <= 2 for part in parts[1:]):
            year, month, day = map(int, parts)
        elif len(digits) == 8:
            year, month, day = int(digits[:4]), int(digits[4:6]), int(digits[6:])
        else:
            return match[0]
        try:
            parsed = date(year, month, day)
        except ValueError:
            return match[0]
        return parsed.isoformat()

    # Only explicit birth-date context and valid YYYYMMDD; 03-04-1990 is
    # deliberately left ambiguous. Hyphenated identifier spelling is phonetic
    # normalization only; examinationNumber is still compared literally.
    text = re.sub(r"(?<!\d)\d+(?:\s*-\s*\d+)+(?!\d)", birth_digits, text)
    text = re.sub(r"\b(дата рождения|date of birth)\s+-\s+", r"\1 ", text)
    text = re.sub(
        r"\b(номер исследования|исследование номер|study number|examination number)\s*[:–—-]?\s*(\d+(?:\s*-\s*\d+)+)",
        lambda match: match[1] + " " + re.sub(r"\D", "", match[2]),
        text,
    )
    return normalize_evaluation_text(text, locale)
