from __future__ import annotations

from typing import Any


def proposal_field_id(proposal: dict[str, Any]) -> str:
    """Read current wire fields and unchanged historical evaluation recordings."""
    value = proposal.get("fieldId", proposal.get("field_id"))
    if not isinstance(value, str) or not value:
        raise ValueError("A recorded proposal must contain a field identifier")
    return value
