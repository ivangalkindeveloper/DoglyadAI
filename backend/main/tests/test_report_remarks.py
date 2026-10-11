from __future__ import annotations

import asyncio
import inspect
import json
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any
from uuid import UUID

import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from starlette.requests import Request

from app.core.language_code import LanguageCode
from app.core.load_configs import load_configs
from app.core.resolve_localized_text import resolve_localized_text
from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_data import USExaminationData
from app.model.ultrasound.us_examination_report import USExaminationReport
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.model.ultrasound.us_examination_scan_photo import USExaminationScanPhoto
from app.prompt import PromptFactory
from app.route.ultrasound import generate_report as route
from app.schema.us_examination_report_structured_output import us_examination_report_structured_output
from tests.support.report_remarks.fake_remarks_service import FakeRemarksService

_PHOTO_ID = UUID("f082b889-b644-49c3-9f17-c31fe2407d98")


@pytest.fixture(autouse=True)
def report_catalogs() -> None:
    load_configs()


def _examination(is_photos_available: bool = True) -> USExaminationData:
    return USExaminationData(
        usExaminationTypeId="echocardiography",
        photos=[USExaminationScanPhoto(id=_PHOTO_ID, data="QUJD")] if is_photos_available else [],
        examinationNumber="Examination#0",
        patientName="Patient",
        patientGender="female",
        patientDateOfBirth=datetime(1990, 1, 1, tzinfo=UTC),
        examinationDescription="Description",
    )


def _remarks() -> list[dict[str, Any]]:
    return [
        {
            "photoId": str(_PHOTO_ID),
            "points": [{"x": 0.42, "y": 0.36, "title": "Image finding", "description": "Image remark"}],
        }
    ]


@pytest.mark.parametrize("language_code", list(LanguageCode))
@pytest.mark.parametrize("is_photo_remarks", [False, True])
@pytest.mark.parametrize("is_description_remarks", [False, True])
@pytest.mark.parametrize("is_photos_available", [False, True])
def test_schema_and_prompt_match_requested_remarks(
    language_code: LanguageCode,
    is_photo_remarks: bool,
    is_description_remarks: bool,
    is_photos_available: bool,
) -> None:
    examination = _examination(is_photos_available)
    schema = json.loads(
        us_examination_report_structured_output(
            include_recommendations=False,
            is_photo_remarks=is_photo_remarks,
            is_description_remarks=is_description_remarks,
            photo_ids=[photo.id for photo in examination.photos],
            language_code=language_code,
        )
    )
    assert ("descriptionRemarks" in schema["properties"]) is is_description_remarks
    assert ("descriptionRemarks" in schema["required"]) is is_description_remarks
    assert ("photoRemarks" in schema["properties"]) is (is_photo_remarks and is_photos_available)
    assert ("photoRemarks" in schema["required"]) is (is_photo_remarks and is_photos_available)
    factory = PromptFactory(language_code)
    system = factory.system_prompt(
        NeuralModelSettings(),
        include_recommendations=False,
        is_photo_remarks=is_photo_remarks and is_photos_available,
        is_description_remarks=is_description_remarks,
    )
    assert ("descriptionRemarks" in system) is is_description_remarks
    assert ("photoRemarks" in system) is (is_photo_remarks and is_photos_available)
    if is_photo_remarks and is_photos_available:
        point = schema["$defs"]["USExaminationPhotoRemarkPoint"]
        assert point["additionalProperties"] is False
        assert set(point["required"]) == {"x", "y", "title", "description"}
        assert "text" not in point["properties"]
        for coordinate in ("x", "y"):
            assert point["properties"][coordinate]["minimum"] == 0
            assert point["properties"][coordinate]["maximum"] == 1
        assert schema["$defs"]["USExaminationPhotoRemarks"]["properties"]["photoId"]["enum"] == [str(_PHOTO_ID)]
    else:
        assert "$defs" not in schema


@pytest.mark.parametrize("language_code", list(LanguageCode))
def test_prompt_binds_supplied_ids_to_image_order(language_code: LanguageCode) -> None:
    examination = _examination()
    second_id = UUID(int=2)
    examination.photos.append(USExaminationScanPhoto(id=second_id, data="REVG"))
    prompt = PromptFactory(language_code).build_prompt(examination, "Title")
    assert f"1: {_PHOTO_ID}\n2: {second_id}" in prompt


@pytest.mark.parametrize("language_code", list(LanguageCode))
def test_report_prompt_uses_catalog_templates_and_preserves_input(language_code: LanguageCode) -> None:
    examination = _examination()
    examination.patientHeight = 170.0
    examination.patientWeight = 65.0
    examination.patientComplaints = "Pain {value}"
    examination.examinationDescription = "Findings {patientName}"
    factory = PromptFactory(language_code)
    prompt = factory.build_prompt(examination, "Title", "Template {value}")
    for key, value in (
        ("reportPatientHeightPrompt", 170.0),
        ("reportPatientWeightPrompt", 65.0),
        ("reportPatientComplaintsPrompt", examination.patientComplaints),
        ("reportExaminationDescriptionPrompt", examination.examinationDescription),
        ("reportTemplatePrompt", "Template {value}"),
    ):
        assert resolve_localized_text(language_code, key).format(value=value) in prompt
    settings = NeuralModelSettings(isMarkdown=False, maxTokens=512)
    system = factory.system_prompt(settings, True, True, True)
    assert system.startswith(resolve_localized_text(language_code, "reportSystemPrompt"))
    assert resolve_localized_text(language_code, "reportTokenLimitPrompt").format(maxTokens=512) in system
    assert resolve_localized_text(language_code, "reportPlainTextPrompt") in system
    assert resolve_localized_text(language_code, "reportRecommendationsPrompt") in system
    assert "title" in system and "description" in system


def test_request_rejects_duplicate_photo_ids() -> None:
    examination = _examination()
    with pytest.raises(ValidationError):
        USExaminationData.model_validate(
            {**examination.model_dump(), "photos": examination.photos + examination.photos}
        )


@pytest.mark.parametrize("value", ["", " \n\t ", None])
def test_blank_optional_template_is_omitted_from_prompt(value: str | None) -> None:
    request = USExaminationRequest(
        neuralModelSettings=NeuralModelSettings(), examinationData=_examination(), template=value
    )
    assert request.template is None
    prompt = PromptFactory(LanguageCode.EN).build_prompt(request.examinationData, "Title", request.template)
    assert "Report template:" not in prompt


def _generate(
    value: dict[str, Any],
    *,
    is_photo_remarks: bool = True,
    is_description_remarks: bool = True,
    is_photos_available: bool = True,
) -> tuple[USExaminationReport, FakeRemarksService]:
    body = USExaminationRequest(
        neuralModelSettings=NeuralModelSettings(selectedNeuralModelId="google/medgemma-4b-it"),
        examinationData=_examination(is_photos_available),
        isPhotoRemarks=is_photo_remarks,
        isDescriptionRemarks=is_description_remarks,
    )
    service = FakeRemarksService({"description": "Description", "conclusion": "Conclusion", **value})
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v1/ultrasound/generate_report",
            "headers": [(b"accept-language", b"en"), (b"x-firebase-appcheck", b"token")],
            "app": SimpleNamespace(state=SimpleNamespace(model_service=service)),
            "state": {"request_id": "a" * 32},
        }
    )
    handler: Any = inspect.unwrap(route.generate_report)
    return asyncio.run(handler(body=body, request=request)), service


def test_route_returns_remarks_with_original_photo_id_and_token() -> None:
    report, service = _generate({"descriptionRemarks": " Description remark ", "photoRemarks": _remarks()})
    assert report.descriptionRemarks == "Description remark"
    assert report.photoRemarks[0].photoId == _PHOTO_ID
    assert report.photoRemarks[0].points[0].x == 0.42
    assert report.photoRemarks[0].points[0].title == "Image finding"
    assert report.photoRemarks[0].points[0].description == "Image remark"
    assert service.request is not None
    assert service.request.photos[0].id == _PHOTO_ID
    assert service.request.app_check_token == "token"


@pytest.mark.parametrize("is_photo_remarks", [False, True])
@pytest.mark.parametrize("is_description_remarks", [False, True])
def test_no_remarks_are_valid_for_any_flags(is_photo_remarks: bool, is_description_remarks: bool) -> None:
    report, _ = _generate(
        {"descriptionRemarks": None, "photoRemarks": []},
        is_photo_remarks=is_photo_remarks,
        is_description_remarks=is_description_remarks,
    )
    assert report.descriptionRemarks is None
    assert report.photoRemarks == []


@pytest.mark.parametrize("coordinate", ["x", "y"])
@pytest.mark.parametrize("value", [-0.1, 1.1, float("nan"), float("inf")])
def test_route_rejects_invalid_point_coordinates(coordinate: str, value: float) -> None:
    remarks = _remarks()
    remarks[0]["points"][0][coordinate] = value
    with pytest.raises(HTTPException) as error:
        _generate({"photoRemarks": remarks})
    assert error.value.status_code == 502


@pytest.mark.parametrize(
    "defect", ["unknown_id", "duplicate_id", "blank_title", "blank_description", "empty_points", "extra_field"]
)
def test_route_rejects_invalid_remarks_without_logging_text(defect: str, caplog: pytest.LogCaptureFixture) -> None:
    remarks = _remarks()
    remarks[0]["points"][0]["description"] = "Sensitive generated patient text"
    if defect == "unknown_id":
        remarks[0]["photoId"] = str(UUID(int=3))
    elif defect == "duplicate_id":
        remarks.append(remarks[0])
    elif defect.startswith("blank_"):
        remarks[0]["points"][0][defect.removeprefix("blank_")] = "   "
    elif defect == "empty_points":
        remarks[0]["points"] = []
    else:
        remarks[0]["points"][0]["extra"] = "Sensitive generated patient text"
    with pytest.raises(HTTPException) as error:
        _generate({"photoRemarks": remarks})
    assert error.value.status_code == 502
    assert "Sensitive generated patient text" not in caplog.text


@pytest.mark.parametrize("value", ["", " \n\t ", None])
def test_optional_report_strings_are_null_when_blank(value: str | None) -> None:
    report, _ = _generate({"recommendations": value, "descriptionRemarks": value})
    assert report.model_dump()["recommendations"] is None
    assert report.model_dump()["descriptionRemarks"] is None


def test_photo_remark_strings_are_trimmed() -> None:
    remarks = _remarks()
    remarks[0]["points"][0].update(title=" Image finding ", description=" Image remark \n")
    report, _ = _generate({"photoRemarks": remarks})
    assert report.photoRemarks[0].points[0].title == "Image finding"
    assert report.photoRemarks[0].points[0].description == "Image remark"


@pytest.mark.parametrize(
    ("value", "options"),
    [
        ({"descriptionRemarks": "Unexpected remark"}, {"is_description_remarks": False}),
        ({"photoRemarks": _remarks()}, {"is_photo_remarks": False}),
        ({"photoRemarks": _remarks()}, {"is_photos_available": False}),
    ],
)
def test_route_rejects_unrequested_remarks(value: dict[str, Any], options: dict[str, bool]) -> None:
    with pytest.raises(HTTPException) as error:
        _generate(value, **options)
    assert error.value.status_code == 502
