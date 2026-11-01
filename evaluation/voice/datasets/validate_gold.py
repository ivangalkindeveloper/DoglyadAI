from __future__ import annotations

import math
import re
from datetime import date
from typing import Any

from evaluation.voice.scoring.score_candidate import FIELDS

CLINICAL_FIELDS = ("examinationDescription", "patientComplaints")
ERROR_TYPES = {
    "wrongValue",
    "wrongUnit",
    "wrongAnatomy",
    "wrongSide",
    "negation",
    "omission",
    "hallucination",
    "uncertainty",
    "wrongField",
    "other",
}


def validate_expected_fields(fields: Any) -> None:
    """Validate the gold's transport contract, without inventing medical limits."""
    if not isinstance(fields, dict) or set(fields) - set(FIELDS):
        raise ValueError("Invalid expected fields")
    for field, value in fields.items():
        if field in ("patientHeightCM", "patientWeightKG"):
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
                raise ValueError(f"{field} must be a positive finite number in its declared unit")
        elif not isinstance(value, str) or not value.strip():
            raise ValueError(f"{field} must be a nonblank string")
        elif field == "patientGender" and value not in ("male", "female"):
            raise ValueError("Unknown patientGender")
        elif field == "patientDateOfBirth":
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
                raise ValueError("patientDateOfBirth must be YYYY-MM-DD")
            try:
                date.fromisoformat(value)
            except ValueError as error:
                raise ValueError("Invalid calendar date in patientDateOfBirth") from error


def _texts(value: Any, name: str, *, is_required: bool = False) -> None:
    if (
        not isinstance(value, list)
        or (is_required and not value)
        or any(not isinstance(text, str) or not text.strip() for text in value)
    ):
        raise ValueError(f"{name} must be a list of nonblank strings")
    if len(set(value)) != len(value):
        raise ValueError(f"Duplicate {name}")


def validate_gold_annotations(case: dict[str, Any]) -> None:
    fields = case["expectedFields"]
    evidence = case.get("fieldEvidence", {})
    if not isinstance(evidence, dict) or set(evidence) != set(fields):
        raise ValueError("Every expected field needs explicit transcript evidence")
    for field, quotes in evidence.items():
        _texts(quotes, "source quotes", is_required=True)
        if any(quote not in case["referenceText"] for quote in quotes):
            raise ValueError(f"Missing source quote for {field}")
    annotations = case.get("clinicalGold", {})
    if not isinstance(annotations, dict):
        raise ValueError("clinicalGold must be an object")
    for field, annotation in annotations.items():
        if field not in CLINICAL_FIELDS or field not in fields or not isinstance(annotation, dict):
            raise ValueError("Clinical annotation must refer to an expected clinical field")
        if annotation.get("reviewStatus") not in ("draft", "singleReviewed", "adjudicated") or not isinstance(
            annotation.get("isComplete"), bool
        ):
            raise ValueError("Clinical annotation needs an explicit review status and boolean isComplete")
        facts = annotation.get("facts")
        if not isinstance(facts, list) or not facts:
            raise ValueError("Clinical facts must be a nonempty list")
        ids = set()
        for fact in facts:
            if (
                not isinstance(fact, dict)
                or not isinstance(fact.get("id"), str)
                or not fact["id"].strip()
                or fact["id"] in ids
            ):
                raise ValueError("Clinical facts must have distinct nonblank IDs")
            ids.add(fact["id"])
            quote = fact.get("sourceQuote")
            if not isinstance(quote, str) or not quote.strip() or quote not in fields[field]:
                raise ValueError("Clinical phrase must be grounded in the expected field")
            _texts(fact.get("acceptedTexts", []), "accepted clinical phrases")
        _texts(annotation.get("acceptedTexts", []), "accepted clinical texts")
        judgments = annotation.get("candidateJudgments", [])
        if not isinstance(judgments, list):
            raise ValueError("candidateJudgments must be a list")
        candidates = set()
        for judgment in judgments:
            if (
                not isinstance(judgment, dict)
                or judgment.get("verdict") not in ("equivalent", "incorrect")
                or not isinstance(judgment.get("candidateText"), str)
            ):
                raise ValueError("Invalid candidate judgment")
            text = judgment["candidateText"]
            if text in candidates:
                raise ValueError("Conflicting candidate judgments")
            candidates.add(text)
            errors = judgment.get("errorTypes", [])
            _texts(errors, "clinical error types")
            if set(errors) - ERROR_TYPES or (judgment["verdict"] == "incorrect") != bool(errors):
                raise ValueError("Clinical verdict and error classification disagree")
    actions = case.get("expectedActions", {})
    if not isinstance(actions, dict) or set(actions) - set(FIELDS):
        raise ValueError("Unknown expected field action")
    for field, action in actions.items():
        if not isinstance(action, dict) or action.get("action") not in ("accept", "review", "omit"):
            raise ValueError("Unknown expected field action")
        if action["action"] == "accept" and field not in fields:
            raise ValueError("Cannot accept a field absent from gold")
        if action["action"] == "omit" and field in fields:
            raise ValueError("Cannot omit a field present in gold")
        quote = action.get("sourceQuote")
        if action["action"] == "review" and (
            not isinstance(quote, str) or not quote.strip() or quote not in case["referenceText"]
        ):
            raise ValueError("Review expectations need the affected source fragment")
