from __future__ import annotations

from functools import lru_cache


@lru_cache(maxsize=65536)
def word_error_counts(reference: tuple[str, ...], actual: tuple[str, ...]) -> dict[str, int | float | None]:
    """Unit-cost Levenshtein alignment with explicit S/D/I and denominators."""
    previous = [(j, 0, 0, j) for j in range(len(actual) + 1)]
    for i, expected in enumerate(reference, 1):
        current = [(i, 0, i, 0)]
        for j, received in enumerate(actual, 1):
            cost, substitutions, deletions, insertions = previous[j - 1]
            mismatch = int(expected != received)
            diagonal = (cost + mismatch, substitutions + mismatch, deletions, insertions)
            cost, substitutions, deletions, insertions = previous[j]
            deletion = (cost + 1, substitutions, deletions + 1, insertions)
            cost, substitutions, deletions, insertions = current[j - 1]
            insertion = (cost + 1, substitutions, deletions, insertions + 1)
            current.append(min((diagonal, deletion, insertion), key=lambda row: row[0]))
        previous = current
    errors, substitutions, deletions, insertions = previous[-1]
    return {
        "referenceWords": len(reference),
        "hypothesisWords": len(actual),
        "substitutions": substitutions,
        "deletions": deletions,
        "insertions": insertions,
        "errors": errors,
        "wer": errors / len(reference) if reference else None,
    }
