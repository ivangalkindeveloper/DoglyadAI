from __future__ import annotations

import re
from typing import Any

import pytest
from fastapi.routing import APIRoute
from pydantic import TypeAdapter, ValidationError

from app.main import app
from app.model.ultrasound.us_examination_ready_made_template_response import USExaminationReadyMadeTemplateResponse
from app.model.ultrasound.us_voice_form_parse_response import USVoiceFormParseResponse


def _assert_camel_case_properties(value: Any) -> None:
    if isinstance(value, dict):
        for name in value.get("properties", {}):
            assert re.fullmatch(r"[a-z][a-zA-Z0-9]*", name), name
        for nested in value.values():
            _assert_camel_case_properties(nested)
    elif isinstance(value, list):
        for nested in value:
            _assert_camel_case_properties(nested)


def test_every_modeled_http_response_has_camel_case_properties() -> None:
    for route in app.routes:
        if isinstance(route, APIRoute) and route.response_model is not None:
            _assert_camel_case_properties(TypeAdapter(route.response_model).json_schema())


@pytest.mark.parametrize("field", ["id", "examinationType", "title", "content"])
@pytest.mark.parametrize("blank", ["", " ", "\n\t"])
def test_template_responses_reject_blank_required_text(field: str, blank: str) -> None:
    data = {"id": "template", "examinationType": "type", "title": "Title", "content": "Content"}
    data[field] = blank
    with pytest.raises(ValidationError):
        USExaminationReadyMadeTemplateResponse.model_validate(data)


def test_voice_response_uses_field_id_camel_case_without_alias() -> None:
    proposal = {"fieldId": "patient_weight_kg", "value": 72, "evidence": "weight 72", "accuracy": "full"}
    result = USVoiceFormParseResponse.model_validate(
        {"proposals": [proposal], "rejectedFieldIds": [], "unmappedFindings": []}
    )
    assert result.model_dump(mode="json")["proposals"][0] == proposal
    proposal["field_id"] = proposal.pop("fieldId")
    with pytest.raises(ValidationError):
        USVoiceFormParseResponse.model_validate(
            {"proposals": [proposal], "rejectedFieldIds": [], "unmappedFindings": []}
        )


@pytest.mark.parametrize("field", ["value", "evidence"])
def test_voice_response_rejects_blank_required_text(field: str) -> None:
    proposal: dict[str, Any] = {
        "fieldId": "patient_name",
        "value": "Patient",
        "evidence": "patient Patient",
        "accuracy": "full",
    }
    proposal[field] = " \n "
    with pytest.raises(ValidationError):
        USVoiceFormParseResponse.model_validate(
            {"proposals": [proposal], "rejectedFieldIds": [], "unmappedFindings": []}
        )
