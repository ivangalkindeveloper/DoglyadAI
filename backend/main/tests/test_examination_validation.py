from __future__ import annotations

from typing import Any
from unittest.mock import AsyncMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.core.get_report_generation_service import get_report_generation_service
from app.core.verify_app_check import verify_app_check
from app.model.ultrasound.us_examination_data import USExaminationData
from app.service.report_generation_service import ReportGenerationService


@pytest.fixture
def examination() -> dict[str, Any]:
    return {
        "usExaminationTypeId": "bladder",
        "photos": [],
        "examinationNumber": "TEST-1",
        "patientName": "Test Patient",
        "patientGender": "female",
        "patientDateOfBirth": "1990-01-01T00:00:00Z",
        "examinationDescription": "Synthetic examination",
    }


@pytest.mark.parametrize("gender", ["male", "female"])
@pytest.mark.parametrize("measurement", [None, 0.1, 65, 170.5])
def test_supported_gender_and_positive_optional_measurements(
    examination: dict[str, Any], gender: str, measurement: float | None
) -> None:
    examination.update(patientGender=gender, patientHeight=measurement, patientWeight=measurement)
    value = USExaminationData.model_validate(examination)
    assert value.patientGender == gender
    assert value.patientHeight == measurement
    assert value.patientWeight == measurement


@pytest.mark.parametrize("field", ["patientHeight", "patientWeight"])
@pytest.mark.parametrize("value", [0, -1, float("nan"), float("inf"), float("-inf"), True, "170"])
def test_measurements_reject_non_positive_non_finite_and_non_numeric_values(
    examination: dict[str, Any], field: str, value: object
) -> None:
    examination[field] = value
    with pytest.raises(ValidationError) as raised:
        USExaminationData.model_validate(examination)
    assert raised.value.errors()[0]["loc"] == (field,)


@pytest.mark.parametrize("field,value", [("patientGender", "unknown"), ("patientHeight", -1), ("patientWeight", 0)])
def test_invalid_examination_returns_field_error_before_generation(
    app: FastAPI, examination: dict[str, Any], field: str, value: object
) -> None:
    examination[field] = value
    service = AsyncMock(spec=ReportGenerationService)
    app.dependency_overrides[verify_app_check] = lambda: None
    app.dependency_overrides[get_report_generation_service] = lambda: service
    client = TestClient(app)
    try:
        response = client.post(
            "/v1/ultrasound/generate_report",
            json={
                "settingsAI": {},
                "examinationData": examination,
                "isRecommendationsIncluded": False,
                "isPhotoRemarks": False,
                "isDescriptionRemarks": False,
            },
        )
    finally:
        client.close()
    assert response.status_code == 422
    assert response.json()["code"] == "invalidRequest"
    assert response.json()["fields"][0]["location"] == ["body", "examinationData", field]
    service.generate.assert_not_called()
