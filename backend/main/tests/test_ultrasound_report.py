from __future__ import annotations

import asyncio
import json
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any
from unittest.mock import AsyncMock

import pytest
from starlette.requests import Request

from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.core.localization.language_code import LanguageCode
from app.error import ApiError
from app.model.settings_ai import SettingsAI
from app.model.ultrasound.us_examination_data import USExaminationData
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.prompt import PromptFactory
from app.service.report import report_generation_service as report_generation_module
from app.service.report.report_generation_service import ReportGenerationService
from tests.support.ultrasound_report.fake_neural_model_service import FakeNeuralModelService
from tests.support.ultrasound_report.fake_prompt_factory import FakePromptFactory

_CONFIG_DIR = Variables(
    environment="development",
).configuration_directory
_CONFIG_BASE = _CONFIG_DIR.parent


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
def test_report_excludes_dictation_vocabulary_and_preserves_valid_term_repairs(
    configuration: Configuration,
    language: LanguageCode,
    raw: str,
    corrected: str,
) -> None:
    service = SimpleNamespace(
        call=AsyncMock(
            return_value=json.dumps(
                {"description": corrected, "conclusion": corrected},
            ),
        ),
    )
    body = USExaminationRequest(
        settingsAI=SettingsAI(
            selectedNeuralModelId="google/medgemma-4b-it",
        ),
        examinationData=USExaminationData(
            usExaminationTypeId="bladder",
            photos=[],
            examinationNumber="UNIT-42",
            patientName="Test Patient",
            patientGender="female",
            patientDateOfBirth=datetime(
                1991,
                1,
                1,
                tzinfo=UTC,
            ),
            examinationDescription=raw,
            isPatientPreparedForExamination=True,
            isPatientConsent=True,
        ),
        isRecommendationsIncluded=False,
    )
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v1/ultrasound/report_generations",
            "headers": [(b"accept-language", language.value.encode())],
            "app": SimpleNamespace(
                state=SimpleNamespace(
                    model_service=service,
                ),
            ),
            "state": {"request_id": "c" * 32},
        },
    )
    handler: Any = ReportGenerationService(
        configuration,
        request.app.state.model_service,
    ).generate
    report = asyncio.run(
        handler(
            body=body,
            language_code=configuration.language(
                request.headers.get(
                    "Accept-Language",
                ),
            ),
            app_check_token=request.headers.get(
                "X-Firebase-AppCheck",
            ),
            request_id=request.state.request_id,
        ),
    )
    generation = service.call.call_args.args[0]
    assert "contextualStrings" not in generation.prompt
    assert "contextualStrings" not in generation.system_prompt
    correction_prompt = configuration.text(
        language,
        "medicalTermCorrectionPrompt",
    )
    assert correction_prompt not in generation.system_prompt
    assert (
        correction_prompt
        in PromptFactory(
            language,
            configuration,
        ).voice_system_prompt()
    )
    assert raw in generation.prompt
    assert report.description == corrected
    assert report.conclusion == corrected


@pytest.mark.parametrize(
    "invalid_report",
    [False, True],
)
def test_route_builds_complete_report_with_the_prompt_factory_contract(
    configuration: Configuration,
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
    invalid_report: bool,
) -> None:
    model = USExaminationNeuralModel(
        id="google/medgemma-4b-it",
        title="MedGemma 4B",
        format="BF16",
        entitlement="base",
        accessibility=USExaminationNeuralModelAccessibility.AVAILABLE,
        contextLength=128000,
        descriptionLocaleKey="googleMedGemma4BDescription",
    )
    monkeypatch.setitem(
        configuration.neural_models,
        model.id,
        model,
    )
    monkeypatch.setattr(
        report_generation_module,
        "PromptFactory",
        FakePromptFactory,
    )

    body = USExaminationRequest(
        settingsAI=SettingsAI(
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
            patientDateOfBirth=datetime(
                1990,
                1,
                1,
                tzinfo=UTC,
            ),
            patientHeight=170,
            patientWeight=65,
            patientComplaints="Complaint",
            examinationDescription="Description",
            isPatientPreparedForExamination=True,
            isPatientConsent=True,
        ),
        template="Template",
        isRecommendationsIncluded=True,
    )
    app = SimpleNamespace(
        state=SimpleNamespace(
            model_service=FakeNeuralModelService(
                invalid_report=invalid_report,
            ),
        ),
    )
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v1/ultrasound/report_generations",
            "headers": [
                (b"accept-language", b"en_US"),
                (b"x-firebase-appcheck", b"app-check-token"),
            ],
            "app": app,
            "state": {"request_id": "a" * 32},
        },
    )

    handler: Any = ReportGenerationService(
        configuration,
        request.app.state.model_service,
    ).generate
    if invalid_report:
        with pytest.raises(
            ApiError,
        ) as error:
            asyncio.run(
                handler(
                    body=body,
                    language_code=configuration.language(
                        request.headers.get(
                            "Accept-Language",
                        ),
                    ),
                    app_check_token=request.headers.get(
                        "X-Firebase-AppCheck",
                    ),
                    request_id=request.state.request_id,
                ),
            )
        assert error.value.status_code == 502
        assert (
            type(
                error.value.__cause__,
            ).__name__
            == "ValidationError"
        )
        assert "Sensitive generated patient text" not in caplog.text
        assert all(
            (record.exc_info is None for record in caplog.records),
        )
        return
    report = asyncio.run(
        handler(
            body=body,
            language_code=configuration.language(
                request.headers.get(
                    "Accept-Language",
                ),
            ),
            app_check_token=request.headers.get(
                "X-Firebase-AppCheck",
            ),
            request_id=request.state.request_id,
        ),
    )

    assert report.modelId == model.id
    assert report.description == "Generated description"
    assert report.conclusion == "Generated conclusion"
    assert report.recommendations == "Generated recommendations"


def test_report_schema_can_exclude_optional_recommendations(
    configuration: Configuration,
) -> None:
    from app.schema.us_examination_report_structured_output import us_examination_report_structured_output

    schema = json.loads(
        us_examination_report_structured_output(
            is_recommendations_included=False,
            is_photo_remarks=False,
            is_description_remarks=False,
            photo_ids=[],
            language_code=LanguageCode.EN,
            localization=configuration.l10n,
        ),
    )

    assert set(
        schema["properties"],
    ) == {"description", "conclusion"}
    assert set(
        schema["required"],
    ) == {"description", "conclusion"}


def test_blank_complaints_are_omitted_and_recommendations_can_be_disabled(
    configuration: Configuration,
) -> None:
    examination = USExaminationData(
        usExaminationTypeId="echocardiography",
        photos=[],
        examinationNumber="Examination#0",
        patientName="Patient",
        patientGender="female",
        patientDateOfBirth=datetime(
            1990,
            1,
            1,
            tzinfo=UTC,
        ),
        patientHeight=170,
        patientWeight=65,
        patientComplaints="   ",
        examinationDescription="Description",
        isPatientPreparedForExamination=True,
        isPatientConsent=True,
    )
    factory = PromptFactory(
        LanguageCode.EN,
        configuration,
    )

    assert examination.patientComplaints is None
    assert "Examination number: Examination#0" in factory.build_prompt(
        examination,
        "Echocardiography",
    )
    assert "Patient complaints:" not in factory.build_prompt(
        examination,
        "Echocardiography",
    )
    assert "Do not generate or include recommendations" in factory.system_prompt(
        SettingsAI(),
        is_recommendations_included=False,
        is_photo_remarks=False,
        is_description_remarks=False,
        structured_output="{}",
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
@pytest.mark.parametrize(
    "language",
    ["en", "ru"],
)
def test_optional_patient_measurements(
    configuration: Configuration,
    measurements: dict[str, float | None],
    language: str,
) -> None:
    examination = USExaminationData.model_validate(
        {
            "usExaminationTypeId": "echocardiography",
            "photos": [],
            "examinationNumber": "Examination#0",
            "patientName": "Patient",
            "patientGender": "female",
            "patientDateOfBirth": "1990-01-01T00:00:00Z",
            "examinationDescription": "Description",
            "isPatientPreparedForExamination": True,
            **measurements,
            "isPatientConsent": True,
        },
    )
    factory = PromptFactory(
        LanguageCode(
            language,
        ),
        configuration,
    )
    prompt = factory.build_prompt(
        examination,
        "Echocardiography",
    )
    height_label = "Patient height:" if language == "en" else "Рост пациента:"
    weight_label = "Patient weight:" if language == "en" else "Вес пациента:"

    assert examination.patientHeight == measurements.get(
        "patientHeight",
    )
    assert examination.patientWeight == measurements.get(
        "patientWeight",
    )
    assert (height_label in prompt) == (examination.patientHeight is not None)
    assert (weight_label in prompt) == (examination.patientWeight is not None)
    assert "None" not in prompt
    if examination.patientHeight is not None:
        assert f"{height_label} {examination.patientHeight}" in prompt
    if examination.patientWeight is not None:
        assert f"{weight_label} {examination.patientWeight}" in prompt
