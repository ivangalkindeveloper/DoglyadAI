from __future__ import annotations

import asyncio
import inspect
import json
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any

import pytest
from starlette.requests import Request

from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_data import USExaminationData
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.prompt.en import PromptFactoryEn
from app.route.ultrasound import generate_report as route
from app.service.base import InferenceRequest


class FakePromptFactory:
    def system_prompt(
        self,
        settings: NeuralModelSettings,
        include_recommendations: bool,
    ) -> str:
        assert settings.selectedNeuralModelId == "google/medgemma-4b-it"
        assert include_recommendations is True
        return "system prompt"

    def build_prompt(
        self,
        examination: USExaminationData,
        examination_title: str,
        template: str | None = None,
    ) -> str:
        assert examination.examinationNumber == "Examination#0"
        assert examination.patientName == "Patient"
        assert examination.patientComplaints == "Complaint"
        assert examination_title == "Echocardiography"
        assert template == "Template"
        return "user prompt"


class FakeModelService:
    async def call(self, request: InferenceRequest) -> str:
        assert request.system_prompt == "system prompt"
        assert request.prompt == "user prompt"
        assert request.app_check_token == "app-check-token"
        schema = json.loads(request.structured_output)
        assert set(schema["properties"]) == {"description", "conclusion", "recommendations"}
        assert schema["additionalProperties"] is False
        return json.dumps(
            {
                "description": "Generated description",
                "conclusion": "Generated conclusion",
                "recommendations": "Generated recommendations",
            }
        )


def test_route_builds_complete_report_with_the_prompt_factory_contract(monkeypatch: pytest.MonkeyPatch) -> None:
    model = USExaminationNeuralModel(
        id="google/medgemma-4b-it",
        title="MedGemma 4B",
        accessibility=USExaminationNeuralModelAccessibility.AVAILABLE,
        description={"en": ""},
    )
    monkeypatch.setattr(route, "resolve_neural_model", lambda _model_id: model)
    monkeypatch.setattr(route, "resolve_examination_title", lambda _type_id, _language: "Echocardiography")
    monkeypatch.setattr(route, "resolve_prompt_factory", lambda _language: FakePromptFactory())

    body = USExaminationRequest(
        neuralModelSettings=NeuralModelSettings(
            selectedNeuralModelId=model.id,
            temperature=0.3,
            maxTokens=512,
        ),
        examinationData=USExaminationData(
            usExaminationTypeId="echocardiography",
            photos=[],
            examinationNumber="Examination#0",
            patientName="Patient",
            patientGender="female",
            patientDateOfBirth=datetime(1990, 1, 1, tzinfo=UTC),
            patientHeight=170,
            patientWeight=65,
            patientComplaints="Complaint",
            examinationDescription="Description",
        ),
        template="Template",
        includeRecommendations=True,
    )
    app = SimpleNamespace(state=SimpleNamespace(model_service=FakeModelService()))
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v1/ultrasound/generate_report",
            "headers": [
                (b"accept-language", b"en_US"),
                (b"x-firebase-appcheck", b"app-check-token"),
            ],
            "app": app,
        }
    )

    handler: Any = inspect.unwrap(route.generate_report)
    report = asyncio.run(handler(body=body, request=request))

    assert report.modelId == model.id
    assert report.description == "Generated description"
    assert report.conclusion == "Generated conclusion"
    assert report.recommendations == "Generated recommendations"


def test_report_schema_can_exclude_optional_recommendations() -> None:
    from app.model.ultrasound.us_examination_report import us_examination_report_structured_output

    schema = json.loads(us_examination_report_structured_output(include_recommendations=False))

    assert set(schema["properties"]) == {"description", "conclusion"}
    assert set(schema["required"]) == {"description", "conclusion"}


def test_blank_complaints_are_omitted_and_recommendations_can_be_disabled() -> None:
    examination = USExaminationData(
        usExaminationTypeId="echocardiography",
        photos=[],
        examinationNumber="Examination#0",
        patientName="Patient",
        patientGender="female",
        patientDateOfBirth=datetime(1990, 1, 1, tzinfo=UTC),
        patientHeight=170,
        patientWeight=65,
        patientComplaints="   ",
        examinationDescription="Description",
    )
    factory = PromptFactoryEn()

    assert examination.patientComplaints is None
    assert "Examination number: Examination#0" in factory.build_prompt(examination, "Echocardiography")
    assert "Patient complaints:" not in factory.build_prompt(examination, "Echocardiography")
    assert "Do not generate or include recommendations" in factory.system_prompt(
        NeuralModelSettings(),
        include_recommendations=False,
    )


@pytest.mark.parametrize(
    "measurements",
    [
        {},
        {"patientHeight": None, "patientWeight": None},
        {"patientHeight": 170},
        {"patientWeight": 65},
        {"patientHeight": 170, "patientWeight": 65},
    ],
)
@pytest.mark.parametrize("language", ["en", "ru"])
def test_optional_patient_measurements(measurements: dict[str, float | None], language: str) -> None:
    from app.prompt.ru import PromptFactoryRu

    examination = USExaminationData.model_validate(
        {
            "usExaminationTypeId": "echocardiography",
            "photos": [],
            "examinationNumber": "Examination#0",
            "patientName": "Patient",
            "patientGender": "female",
            "patientDateOfBirth": "1990-01-01T00:00:00Z",
            "examinationDescription": "Description",
            **measurements,
        }
    )
    factory = PromptFactoryEn() if language == "en" else PromptFactoryRu()
    prompt = factory.build_prompt(examination, "Echocardiography")
    height_label = "Patient height:" if language == "en" else "Рост пациента:"
    weight_label = "Patient weight:" if language == "en" else "Вес пациента:"

    assert examination.patientHeight == measurements.get("patientHeight")
    assert examination.patientWeight == measurements.get("patientWeight")
    assert (height_label in prompt) == (examination.patientHeight is not None)
    assert (weight_label in prompt) == (examination.patientWeight is not None)
    assert "None" not in prompt
    if examination.patientHeight is not None:
        assert f"{height_label} {examination.patientHeight}" in prompt
    if examination.patientWeight is not None:
        assert f"{weight_label} {examination.patientWeight}" in prompt
