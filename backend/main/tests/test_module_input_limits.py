from __future__ import annotations

import asyncio
import json
import shutil
from dataclasses import replace
from pathlib import Path
from unittest.mock import AsyncMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.core.configuration.configuration import Configuration
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.configuration.variables import Variables
from app.core.localization.language_code import LanguageCode
from app.error import TextTooLongError
from app.model.application_module_config import ApplicationModuleConfig
from app.model.report_email import ReportEmail
from app.model.ultrasound.us_voice_form_parse_request import USVoiceFormParseRequest
from app.service.configuration.configuration_response_service import ConfigurationResponseService
from app.service.dictation.dictation_parsing_service import DictationParsingService
from app.service.email.report_email_service import ReportEmailService
from app.service.neural_model.neural_model_service import NeuralModelService
from app.service.report.report_generation_jobs import ReportGenerationJobs
from app.service.validation.text_length_validator import TextLengthValidator


@pytest.mark.parametrize(
    "environment",
    ["development", "production"],
)
def test_module_limits_are_published_from_the_validated_configuration(
    environment: str,
) -> None:
    config = ConfigurationLoader(
        Path(
            __file__,
        )
        .resolve()
        .parents[1]
        / "config"
        / environment,
    ).load()
    for language in config.locale.codes:
        document = ConfigurationResponseService(
            config,
        ).application(
            language,
        )
        assert (
            ApplicationModuleConfig.model_validate(
                document,
            )
            == config.modules
        )
    assert "defaultPatientHeightCM" not in config.application["ultrasound"]
    assert "defaultPatientWeightKG" not in config.application["ultrasound"]
    assert "max_transcript_characters" not in config.server.model_dump()


@pytest.mark.parametrize(
    "value",
    [0, -1, True, "64", None],
)
def test_invalid_module_limit_aborts_configuration_loading(
    configuration: Configuration,
    tmp_path: Path,
    value: object,
) -> None:
    source = (
        Path(
            __file__,
        )
        .resolve()
        .parents[1]
        / "config"
        / "development"
    )
    shutil.copytree(
        source,
        tmp_path / "config",
    )
    path = tmp_path / "config" / "application.json"
    document = json.loads(
        path.read_text(),
    )
    document["scan"]["examinationNumberMaxLength"] = value
    path.write_text(
        json.dumps(
            document,
        ),
    )
    with pytest.raises(
        RuntimeError,
        match="Failed to load configs",
    ):
        ConfigurationLoader(
            path.parent,
        ).load()


def test_missing_module_section_is_rejected(
    configuration: Configuration,
) -> None:
    document = dict(
        configuration.application,
    )
    del document["templateEdit"]
    with pytest.raises(
        ValidationError,
    ):
        ApplicationModuleConfig.model_validate(
            document,
        )


@pytest.mark.parametrize(
    "value",
    ["\u0410", "\u0435\u0301", "👨‍👩‍👧‍👦", "🇷🇺", "\r\n"],
)
def test_unicode_limits_count_whole_characters(
    value: str,
) -> None:
    TextLengthValidator.validate(
        value * 3,
        3,
        ["body", "patientName"],
    )
    with pytest.raises(
        TextTooLongError,
    ) as raised:
        TextLengthValidator.validate(
            value * 4,
            3,
            ["body", "patientName"],
        )
    assert raised.value.fields[0].location == ["body", "patientName"]


@pytest.mark.parametrize(
    "field",
    ["examinationNumber", "patientName", "patientComplaints", "examinationDescription"],
)
def test_oversized_examination_fields_are_rejected_before_generation(
    app: FastAPI,
    configuration: Configuration,
    field: str,
    report_jobs: ReportGenerationJobs,
) -> None:
    maximum = getattr(
        configuration.modules.scan,
        field + "MaxLength",
    )
    examination = {
        "usExaminationTypeId": "bladder",
        "photos": [],
        "examinationNumber": "TEST-1",
        "patientName": "Test Patient",
        "patientGender": "female",
        "patientDateOfBirth": "1990-01-01T00:00:00Z",
        "examinationDescription": "Findings",
        "isPatientPreparedForExamination": True,
        "isPatientConsent": True,
    }
    examination[field] = "x" * (maximum + 1)
    client = TestClient(
        app,
    )
    try:
        response = client.post(
            "/v1/ultrasound/report_generations",
            json={
                "requestId": "00000000-0000-0000-0000-000000000001",
                "examination": {"settingsAI": {}, "examinationData": examination},
            },
        )
    finally:
        client.close()
    assert response.status_code == 422
    assert response.json()["code"] == "textTooLong"
    assert response.json()["fields"][0]["location"] == ["body", "examinationData", field]
    assert "x" * (maximum + 1) not in response.text
    report_jobs.store.create.assert_not_called()


def test_ready_made_templates_must_fit_both_editors(
    configuration: Configuration,
) -> None:
    modules = configuration.modules.model_copy(
        update={
            "templateEdit": configuration.modules.templateEdit.model_copy(
                update={"contentMaxLength": 1},
            )
        },
    )
    with pytest.raises(
        ValueError,
        match="Ready-made template",
    ):
        ConfigurationResponseService(
            replace(
                configuration,
                modules=modules,
            ),
        ).validate()


def test_dictation_limit_comes_from_its_module_before_model_execution(
    configuration: Configuration,
) -> None:
    modules = configuration.modules.model_copy(
        update={
            "scanSpeech": configuration.modules.scanSpeech.model_copy(
                update={"transcriptMaxLength": 3},
            )
        },
    )
    model = AsyncMock(
        spec=NeuralModelService,
    )
    service = DictationParsingService(
        replace(
            configuration,
            modules=modules,
        ),
        model,
    )
    with pytest.raises(
        TextTooLongError,
    ) as raised:
        asyncio.run(
            service.parse(
                USVoiceFormParseRequest(
                    usExaminationTypeId="bladder",
                    transcript="Text",
                ),
                language=LanguageCode.EN,
            ),
        )
    assert raised.value.fields[0].location == ["body", "transcript"]
    model.call.assert_not_called()


def test_email_limit_comes_from_work_settings_before_smtp(
    configuration: Configuration,
    variables: Variables,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    smtp = AsyncMock()
    monkeypatch.setattr(
        "app.service.email.report_email_service.smtplib.SMTP",
        smtp,
    )
    settings = configuration.modules.workSettings.model_copy(
        update={"emailMaxLength": 3},
    )
    service = ReportEmailService(
        variables,
        configuration.server.email,
        settings,
    )
    with pytest.raises(
        TextTooLongError,
    ) as raised:
        asyncio.run(
            service.send(
                ReportEmail(
                    recipientEmail="doctor@example.com",
                    subject="Report",
                    body="Body",
                ),
            ),
        )
    assert raised.value.fields[0].location == ["body", "recipientEmail"]
    smtp.assert_not_called()


def test_module_config_fields_match_swift_models(
    configuration: Configuration,
) -> None:
    import re

    root = (
        Path(
            __file__,
        )
        .resolve()
        .parents[3]
        / "ios"
        / "Doglyad"
        / "Domain"
        / "Config"
    )
    for name, field in ApplicationModuleConfig.model_fields.items():
        kind = field.annotation
        assert kind is not None
        source = (root / f"{kind.__name__}.swift").read_text()
        keys = set(
            re.findall(
                r"let (\w+): Int",
                source,
            ),
        )
        assert keys == set(
            type(
                getattr(
                    configuration.modules,
                    name,
                ),
            ).model_fields,
        )
