from __future__ import annotations

import asyncio
import inspect
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
from app.route import ultrasound_conclusion as route
from app.service.base import InferenceRequest


class FakePromptFactory:
    def system_prompt(self, settings: NeuralModelSettings) -> str:
        assert settings.selectedNeuralModelId == "google/medgemma-4b-it"
        return "system prompt"

    def build_prompt(
        self,
        examination: USExaminationData,
        examination_title: str,
        template: str | None = None,
    ) -> str:
        assert examination.patientName == "Patient"
        assert examination_title == "Echocardiography"
        assert template == "Template"
        return "user prompt"


class FakeModelService:
    async def call(self, request: InferenceRequest) -> str:
        assert request.system_prompt == "system prompt"
        assert request.prompt == "user prompt"
        assert request.app_check_token == "app-check-token"
        return "Generated conclusion"


def test_route_builds_prompt_with_the_prompt_factory_contract(monkeypatch: pytest.MonkeyPatch) -> None:
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
            patientName="Patient",
            patientGender="female",
            patientDateOfBirth=datetime(1990, 1, 1, tzinfo=UTC),
            patientHeight=170,
            patientWeight=65,
            patientComplaint="Complaint",
            examinationDescription="Description",
        ),
        template="Template",
    )
    app = SimpleNamespace(state=SimpleNamespace(model_service=FakeModelService()))
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v1/ultrasound_conclusion",
            "headers": [
                (b"accept-language", b"en_US"),
                (b"x-firebase-appcheck", b"app-check-token"),
            ],
            "app": app,
        }
    )

    handler: Any = inspect.unwrap(route.ultrasound_conclusion)
    conclusion = asyncio.run(handler(body=body, request=request))

    assert conclusion.modelId == model.id
    assert conclusion.response == "Generated conclusion"
