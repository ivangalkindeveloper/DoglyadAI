from __future__ import annotations

from evaluation.voice.scoring.normalize_asr_text import normalize_asr_text
from evaluation.voice.scoring.word_error_counts import word_error_counts

SCORER_VERSION = "voice-evaluation-2.1"


def spoken_normalized_wer(reference: str, transcript: str, locale: str) -> float:
    """Display-normalized WER v2; empty references use an explicit sentinel rate.

    Aggregate reports use word_error_counts and report insertions on silence
    separately. Historical results must not be overwritten with v2 scores.
    """
    score = word_error_counts(normalize_asr_text(reference, locale), normalize_asr_text(transcript, locale))
    return float(score["wer"]) if score["wer"] is not None else float(bool(score["insertions"]))
