from __future__ import annotations

import asyncio
import inspect
import json
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any
from unittest.mock import AsyncMock

import pytest
from fastapi import HTTPException
from starlette.requests import Request

from app.core.language_code import LanguageCode
from app.core.load_configs import load_configs
from app.core.resolve_examination_contextual_strings import resolve_examination_contextual_strings
from app.core.resolve_localized_text import resolve_localized_text
from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_data import USExaminationData
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.prompt import PromptFactory
from app.prompt.voice_form_system_prompt import voice_form_system_prompt
from app.route.ultrasound import generate_report as route
from tests.support.ultrasound_report.fake_neural_model_service import FakeNeuralModelService
from tests.support.ultrasound_report.fake_prompt_factory import FakePromptFactory


@pytest.fixture(autouse=True)
def report_catalogs() -> None:
    load_configs()


@pytest.mark.parametrize(
    "language,raw,corrected",
    [
        (
            LanguageCode.RU,
            "Содержимое анофагенное. Стенка 2,7 мм.",
            "Содержимое анэхогенное. Стенка 2,7 мм.",
        ),
        (
            LanguageCode.EN,
            "Anechoeic contents. Wall 2.7 mm.",
            "Anechoic contents. Wall 2.7 mm.",
        ),
    ],
)
def test_report_uses_selected_context_and_the_same_term_correction_rules_as_dictation(
    language: LanguageCode, raw: str, corrected: str
) -> None:
    service = SimpleNamespace(
        call=AsyncMock(return_value=json.dumps({"description": corrected, "conclusion": corrected}))
    )
    body = USExaminationRequest(
        neuralModelSettings=NeuralModelSettings(selectedNeuralModelId="google/medgemma-4b-it"),
        examinationData=USExaminationData(
            usExaminationTypeId="bladder",
            photos=[],
            examinationNumber="UNIT-42",
            patientName="Test Patient",
            patientGender="female",
            patientDateOfBirth=datetime(1991, 1, 1, tzinfo=UTC),
            examinationDescription=raw,
        ),
        isRecommendationsIncluded=False,
    )
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v1/ultrasound/generate_report",
            "headers": [(b"accept-language", language.value.encode())],
            "app": SimpleNamespace(state=SimpleNamespace(model_service=service)),
            "state": {"request_id": "c" * 32},
        }
    )
    handler: Any = inspect.unwrap(route.generate_report)
    report = asyncio.run(handler(body=body, request=request))
    generation = service.call.call_args.args[0]
    context = json.loads(
        next(line for line in generation.prompt.splitlines() if line.startswith('{"contextualStrings":'))
    )
    assert context["contextualStrings"] == resolve_examination_contextual_strings("bladder", language)
    assert context["contextualStrings"] != resolve_examination_contextual_strings("thyroidGland", language)
    correction_prompt = resolve_localized_text(language, "medicalTermCorrectionPrompt")
    assert correction_prompt in generation.system_prompt
    assert correction_prompt in voice_form_system_prompt(language)
    assert raw in generation.prompt
    assert report.description == corrected
    assert report.conclusion == corrected


@pytest.mark.parametrize("invalid_report", [False, True])
def test_route_builds_complete_report_with_the_prompt_factory_contract(
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
    invalid_report: bool,
) -> None:
    model = USExaminationNeuralModel(
        id="google/medgemma-4b-it",
        title="MedGemma 4B",
        entitlement="base",
        accessibility=USExaminationNeuralModelAccessibility.AVAILABLE,
        contextLength=128000,
        descriptionLocaleKey="googleMedGemma4BDescription",
    )
    monkeypatch.setattr(route, "resolve_neural_model", lambda _model_id: model)
    monkeypatch.setattr(route, "resolve_examination_title", lambda _type_id, _language: "Echocardiography")
    monkeypatch.setattr(route, "PromptFactory", FakePromptFactory)

    load_configs()
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
        isRecommendationsIncluded=True,
    )
    app = SimpleNamespace(state=SimpleNamespace(model_service=FakeNeuralModelService(invalid_report=invalid_report)))
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
            "state": {"request_id": "a" * 32},
        }
    )

    handler: Any = inspect.unwrap(route.generate_report)
    if invalid_report:
        with pytest.raises(HTTPException) as error:
            asyncio.run(handler(body=body, request=request))
        assert error.value.status_code == 502
        assert "Generated report does not match the response schema: ValidationError" in caplog.text
        assert "Sensitive generated patient text" not in caplog.text
        assert all(record.exc_info is None for record in caplog.records)
        return
    report = asyncio.run(handler(body=body, request=request))

    assert report.modelId == model.id
    assert report.description == "Generated description"
    assert report.conclusion == "Generated conclusion"
    assert report.recommendations == "Generated recommendations"


def test_report_schema_can_exclude_optional_recommendations() -> None:
    from app.schema.us_examination_report_structured_output import us_examination_report_structured_output

    schema = json.loads(
        us_examination_report_structured_output(
            is_recommendations_included=False,
            is_photo_remarks=False,
            is_description_remarks=False,
            photo_ids=[],
            language_code=LanguageCode.EN,
        )
    )

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
    factory = PromptFactory(LanguageCode.EN)

    assert examination.patientComplaints is None
    assert "Examination number: Examination#0" in factory.build_prompt(examination, "Echocardiography")
    assert "Patient complaints:" not in factory.build_prompt(examination, "Echocardiography")
    assert "Do not generate or include recommendations" in factory.system_prompt(
        NeuralModelSettings(),
        is_recommendations_included=False,
        is_photo_remarks=False,
        is_description_remarks=False,
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
    factory = PromptFactory(LanguageCode(language))
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
