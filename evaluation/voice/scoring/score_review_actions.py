from __future__ import annotations

from typing import Any


def score_review_actions(expected: dict[str, Any], result: dict[str, Any], matches: dict[str, bool]) -> dict[str, Any]:
    """Assess localized review without awarding success for withholding everything."""
    if not expected:
        return {"status": "notAnnotated", "expected": 0, "matched": None, "fields": {}}
    if any(
        not isinstance(value, dict) or value.get("action") not in ("accept", "review", "omit")
        for value in expected.values()
    ):
        raise ValueError("Unknown expected field action")
    if result.get("status") != "ok" or "reviewFieldIds" not in result:
        return {"status": "notMeasured", "expected": len(expected), "matched": None, "fields": {}}
    review = set(result["reviewFieldIds"])
    automatic = set(result.get("automaticFieldIds", []))
    proposed = {key for key, value in result.get("fields", {}).items() if value is not None}
    fields = {}
    for field, annotation in expected.items():
        action = annotation["action"]
        if action == "review":
            fields[field] = field in review and field not in automatic
        elif action == "omit":
            fields[field] = field not in proposed and field not in automatic
        else:
            # Accept means the reliable proposal survives. Whether the policy
            # safely auto-applies it is a separate, confidence-dependent metric.
            fields[field] = field in proposed and matches[field]
    return {
        "status": "measured",
        "expected": len(expected),
        "matched": sum(fields.values()),
        "fields": fields,
        "reliableFieldsSentToReview": sorted(
            field for field in review if expected.get(field, {}).get("action") == "accept"
        ),
    }
