from __future__ import annotations

import asyncio
from collections.abc import Iterator
from datetime import UTC, datetime
from pathlib import Path
from uuid import UUID

import pytest
from fastapi.testclient import TestClient

from app.core import main_lifespan
from app.core.language_code import LanguageCode
from app.core.neural_model_service_type import NeuralModelServiceType
from app.core.variables import variables
from app.core.verify_app_check import verify_app_check
from app.model.mock.mock_report_fixture import MockReportFixture
from app.model.mock.mock_voice_form_fixture import MockVoiceFormFixture
from app.model.neural_model.neural_model_service_operation import NeuralModelServiceOperation
from app.model.neural_model.neural_model_service_request import NeuralModelServiceRequest
from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_data import USExaminationData
from app.model.ultrasound.us_examination_model_report_response import USExaminationModelReportResponse
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.model.ultrasound.us_examination_scan_photo import USExaminationScanPhoto
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.model.ultrasound.us_voice_form_parse_response import USVoiceFormParseResponse
from app.prompt.voice_form_prompt import voice_form_prompt
from app.service.mock_neural_model_service import MockNeuralModelService

_FIXTURES_DIR = Path(__file__).resolve().parents[1] / "app" / "mock"
_PHOTO_IDS = [UUID(int=123), UUID(int=456)]
_MODEL_ID = "google/medgemma-4b-it"


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    from app.main import app

    initialized: list[bool] = []
    monkeypatch.setattr(variables, "model_service_type", NeuralModelServiceType.MOCK)
    monkeypatch.setattr(variables, "inference_endpoints_path", None)
    monkeypatch.setattr(main_lifespan, "init_app_check", lambda: initialized.append(True))
    with TestClient(app) as test_client:
        assert isinstance(app.state.model_service, MockNeuralModelService)
        yield test_client
    assert initialized == [True]
    assert app.state.http_client.is_closed


def _authorize(monkeypatch: pytest.MonkeyPatch) -> None:
    from app.main import app

    async def verified() -> None:
        pass

    monkeypatch.setitem(app.dependency_overrides, verify_app_check, verified)


def _report_request(
    *,
    is_photo_remarks: bool,
    is_description_remarks: bool,
    is_recommendations: bool,
    is_photos_available: bool = True,
) -> USExaminationRequest:
    return USExaminationRequest(
        neuralModelSettings=NeuralModelSettings(selectedNeuralModelId=_MODEL_ID),
        examinationData=USExaminationData(
            usExaminationTypeId="echocardiography",
            photos=[USExaminationScanPhoto(id=photo_id, data="QUJD") for photo_id in _PHOTO_IDS]
            if is_photos_available
            else [],
            examinationNumber="123",
            patientName="Test patient",
            patientGender="male",
            patientDateOfBirth=datetime(1985, 1, 15, tzinfo=UTC),
            examinationDescription="Test description",
        ),
        isRecommendationsIncluded=is_recommendations,
        isPhotoRemarks=is_photo_remarks,
        isDescriptionRemarks=is_description_remarks,
    )


def test_mock_startup_still_initializes_and_requires_app_check(client: TestClient) -> None:
    assert client.get("/v1/application_config").status_code == 401
    assert client.post("/v1/ultrasound/generate_report", json={}).status_code == 401
    assert client.post("/v1/ultrasound/parse_dictation", json={}).status_code == 401


@pytest.mark.parametrize("language", list(LanguageCode))
@pytest.mark.parametrize(
    "is_photo_remarks,is_description_remarks,is_recommendations",
    [(True, True, True), (False, False, False), (True, False, False), (False, True, True)],
)
def test_mock_report_respects_flags_language_and_uploaded_ids(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
    language: LanguageCode,
    is_photo_remarks: bool,
    is_description_remarks: bool,
    is_recommendations: bool,
) -> None:
    _authorize(monkeypatch)
    body = _report_request(
        is_photo_remarks=is_photo_remarks,
        is_description_remarks=is_description_remarks,
        is_recommendations=is_recommendations,
    )
    fixture = MockReportFixture.model_validate_json(
        (_FIXTURES_DIR / language.value / "report.json").read_text(encoding="utf-8")
    )

    response = client.post(
        "/v1/ultrasound/generate_report",
        headers={"Accept-Language": language.value},
        json=body.model_dump(mode="json"),
    )

    assert response.status_code == 200, response.text
    report = USExaminationModelReportResponse.model_validate(response.json())
    assert report.modelId == _MODEL_ID
    assert report.description == fixture.report.description
    assert report.conclusion == fixture.report.conclusion
    assert report.descriptionRemarks == (fixture.report.descriptionRemarks if is_description_remarks else None)
    assert report.recommendations == (fixture.report.recommendations if is_recommendations else None)
    assert [remarks.photoId for remarks in report.photoRemarks] == (_PHOTO_IDS if is_photo_remarks else [])
    assert all(remarks.points == fixture.photoRemarkPoints for remarks in report.photoRemarks)


def test_mock_report_does_not_invent_photos(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    _authorize(monkeypatch)
    body = _report_request(
        is_photo_remarks=True,
        is_description_remarks=True,
        is_recommendations=True,
        is_photos_available=False,
    )

    response = client.post("/v1/ultrasound/generate_report", json=body.model_dump(mode="json"))

    assert response.status_code == 200, response.text
    assert response.json()["photoRemarks"] == []


@pytest.mark.parametrize("max_tokens", [None, 4096], ids=["application-default", "inference-limit"])
def test_mock_report_accepts_client_neural_model_settings(
    client: TestClient, monkeypatch: pytest.MonkeyPatch, max_tokens: int | None
) -> None:
    _authorize(monkeypatch)
    settings = client.get("/v1/application_config").json()["ultrasound"]["neuralModel"]
    if max_tokens is not None:
        settings["maxTokens"] = max_tokens
    body = _report_request(
        is_photo_remarks=True,
        is_description_remarks=True,
        is_recommendations=True,
    ).model_dump(mode="json")
    body["neuralModelSettings"].update(settings)

    response = client.post("/v1/ultrasound/generate_report", json=body)

    assert response.status_code == 200, response.text
    assert response.json()["modelId"] == _MODEL_ID


@pytest.mark.parametrize("max_tokens", [0, 4097])
def test_mock_report_rejects_token_limits_outside_inference_range(
    client: TestClient, monkeypatch: pytest.MonkeyPatch, max_tokens: int
) -> None:
    _authorize(monkeypatch)
    body = _report_request(
        is_photo_remarks=True,
        is_description_remarks=True,
        is_recommendations=True,
    ).model_dump(mode="json")
    body["neuralModelSettings"]["maxTokens"] = max_tokens

    response = client.post("/v1/ultrasound/generate_report", json=body)

    assert response.status_code == 422
    assert response.json()["detail"][0]["loc"] == ["body", "neuralModelSettings", "maxTokens"]


@pytest.mark.parametrize("language", list(LanguageCode))
def test_mock_voice_scenario_passes_the_real_source_validator(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
    language: LanguageCode,
) -> None:
    _authorize(monkeypatch)
    fixture = MockVoiceFormFixture.model_validate_json(
        (_FIXTURES_DIR / language.value / "voice_form.json").read_text(encoding="utf-8")
    )

    response = client.post(
        "/v1/ultrasound/parse_dictation",
        headers={"Accept-Language": language.value},
        json={"usExaminationTypeId": "abdominalCavity", "transcript": fixture.transcript},
    )

    assert response.status_code == 200, response.text
    result = USVoiceFormParseResponse.model_validate(response.json())
    assert {item.fieldId for item in result.proposals} == set(USVoiceFieldId)

    values = {item.fieldId: item.value for item in result.proposals}
    assert values[USVoiceFieldId.PATIENT_NAME] == fixture.generation.root[1].value
    assert values[USVoiceFieldId.PATIENT_DATE_OF_BIRTH] == "1985-01-15"
    assert values[USVoiceFieldId.PATIENT_GENDER] == "male"
    assert values[USVoiceFieldId.PATIENT_HEIGHT_CM] == 180
    assert values[USVoiceFieldId.PATIENT_WEIGHT_KG] == 75


@pytest.mark.parametrize("language", list(LanguageCode))
@pytest.mark.parametrize("transcript", ["Unrelated input", "Patient John Smith. Patient John Smith."])
def test_mock_voice_does_not_return_missing_or_ambiguous_evidence(
    language: LanguageCode,
    transcript: str,
) -> None:
    request = NeuralModelServiceRequest(
        operation=NeuralModelServiceOperation.PARSE_DICTATION,
        language_code=language,
        model_id=_MODEL_ID,
        system_prompt="",
        prompt=voice_form_prompt("Title", transcript),
        structured_output=USVoiceFormGeneration.structured_output(),
    )

    generated = asyncio.run(MockNeuralModelService().call(request))

    assert USVoiceFormGeneration.model_validate_json(generated).root == []
