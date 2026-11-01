from __future__ import annotations

import hashlib
from typing import Any

from evaluation.voice.scoring.normalize_evaluation_text import normalize_evaluation_text


def score_clinical_content(
    expected: str, actual: str | None, locale: str, annotation: dict[str, Any] | None = None
) -> dict[str, Any]:
    """Match independently reviewed whole facts, not a bag of critical tokens.

    Unknown wording is unassessed, not a proven error or a proven equivalence.
    The result cannot certify correctness unless annotations are reviewed and
    exhaustive, every expected fact matches, and no content is left unassessed.
    """
    is_reviewed = bool(
        annotation and annotation.get("isComplete") is True and annotation.get("reviewStatus") == "adjudicated"
    )
    result: dict[str, Any] = {
        "status": "notAnnotated" if annotation is None else "pendingReview",
        "isClinicallyEquivalent": None,
        "expectedFacts": len(annotation.get("facts", [])) if annotation else 0,
        "matchedFacts": [],
        "unmatchedFacts": [],
        "unassessedTokens": [],
        "candidateSha256": hashlib.sha256((actual or "").encode()).hexdigest(),
        "reviewStatus": annotation.get("reviewStatus", "draft") if annotation else "notAnnotated",
    }
    if not is_reviewed:
        return result
    if not isinstance(annotation.get("facts"), list) or not annotation["facts"]:
        raise ValueError("A complete clinical annotation must contain facts")
    # A blinded expert judgment is bound to the exact candidate, so a changed
    # output cannot inherit a previous clinical approval.
    for judgment in annotation.get("candidateJudgments", []):
        if judgment.get("candidateText") == actual:
            result.update(
                status="adjudicated",
                isClinicallyEquivalent=judgment["verdict"] == "equivalent",
                errorTypes=judgment.get("errorTypes", []),
            )
            return result
    received = normalize_evaluation_text(actual or "", locale, is_convert_units=True)
    variants = [expected, *annotation.get("acceptedTexts", [])]
    if actual is not None and any(
        received == normalize_evaluation_text(value, locale, is_convert_units=True) for value in variants
    ):
        result.update(
            status="matched", isClinicallyEquivalent=True, matchedFacts=[fact["id"] for fact in annotation["facts"]]
        )
        return result
    used: set[int] = set()
    for fact in annotation["facts"]:
        alternatives = [fact["sourceQuote"], *fact.get("acceptedTexts", [])]
        matched: set[int] | None = None
        for phrase in alternatives:
            reference = normalize_evaluation_text(phrase, locale, is_convert_units=True)
            if not reference:
                raise ValueError("A clinical fact cannot match an empty phrase")
            for start in range(len(received) - len(reference) + 1):
                positions = set(range(start, start + len(reference)))
                if not positions & used and received[start : start + len(reference)] == reference:
                    matched = positions
                    break
            if matched is not None:
                break
        if matched is not None:
            used.update(matched)
            result["matchedFacts"].append(fact["id"])
        else:
            result["unmatchedFacts"].append(fact["id"])
    result["unassessedTokens"] = [token for index, token in enumerate(received) if index not in used]
    if actual is None:
        result.update(status="missing", isClinicallyEquivalent=False)
    elif not result["unmatchedFacts"] and not result["unassessedTokens"]:
        result.update(status="matched", isClinicallyEquivalent=True)
    else:
        result["status"] = "requiresAdjudication"
    return result
