from __future__ import annotations

import json
from datetime import UTC, datetime

import pytest
from pydantic import ValidationError

from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.model.settings_ai import SettingsAI
from app.model.ultrasound.us_examination_data import USExaminationData
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.prompt import PromptFactory
from app.service.dictation.voice_form_validator import VoiceFormValidator
from tests.support.voice_form_parsing.voice_source_localization_test_support import (
    voice_source_localization_test_support,
)


@pytest.mark.parametrize(
    "text,is_ready",
    [
        ("Пациент подготовлен к исследованию.", True),
        ("Пациент не подготовлен к исследованию.", False),
        ("Пациентка не готова к исследованию.", False),
        ("Пациент к исследованию подготовлен.", True),
        ("The patient is prepared for the examination.", True),
        ("The patient is not prepared for the examination.", False),
        ("The patient is unprepared.", False),
        ("Мочевой пузырь недостаточно наполнен.", None),
        ("Пациент готов?", None),
        ("Возможно пациент подготовлен.", None),
        ("Если пациент подготовлен, продолжим.", None),
        ("Пациент подготовлен. Пациент не подготовлен.", None),
        ("Maybe the patient is ready.", None),
        ("If the patient is prepared, continue.", None),
        ("The patient is ready. The patient is not ready.", None),
    ],
)
def test_voice_readiness_requires_explicit_source(
    text: str,
    is_ready: bool | None,
) -> None:
    # Even a confident model cannot invent this flag or invert spoken negation.
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "is_patient_prepared_for_examination", "value": "true", "evidence": text, "accuracy": "full"}],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            text,
        ),
    ).validate(
        generated,
        text,
    )
    readiness = [p for p in response.proposals if p.fieldId is USVoiceFieldId.IS_PATIENT_PREPARED_FOR_EXAMINATION]
    assert [p.value for p in readiness] == ([] if is_ready is None else ["true" if is_ready else "false"])


@pytest.mark.parametrize(
    "is_ready",
    [False, True],
)
@pytest.mark.parametrize(
    "language",
    [LanguageCode.RU, LanguageCode.EN],
)
def test_report_prompt_carries_readiness_without_inventing_findings(
    configuration: Configuration,
    is_ready: bool,
    language: LanguageCode,
) -> None:
    examination = USExaminationData(
        usExaminationTypeId="bladder",
        photos=[],
        examinationNumber="R-001",
        patientName="Test",
        patientGender="female",
        patientDateOfBirth=datetime(
            1990,
            1,
            1,
            tzinfo=UTC,
        ),
        examinationDescription="Test description",
        isPatientPreparedForExamination=is_ready,
        isPatientConsent=True,
    )
    assert (
        json.loads(
            examination.model_dump_json(),
        )["isPatientPreparedForExamination"]
        is is_ready
    )
    factory = PromptFactory(
        language,
        configuration,
    )
    prompt = factory.build_prompt(
        examination,
        examination_title="Test",
    )
    key = "reportPatientPreparedPrompt" if is_ready else "reportPatientUnpreparedPrompt"
    opposite = "reportPatientUnpreparedPrompt" if is_ready else "reportPatientPreparedPrompt"
    assert (
        configuration.text(
            language,
            key,
        )
        in prompt
    )
    assert (
        configuration.text(
            language,
            opposite,
        )
        not in prompt
    )
    enabled = factory.system_prompt(
        SettingsAI(
            selectedNeuralModelId="test",
            isMarkdown=True,
            temperature=None,
            maxTokens=None,
        ),
        False,
        False,
        True,
        "{}",
    )
    disabled = factory.system_prompt(
        SettingsAI(
            selectedNeuralModelId="test",
            isMarkdown=True,
            temperature=None,
            maxTokens=None,
        ),
        False,
        False,
        False,
        "{}",
    )
    assert (
        configuration.text(
            language,
            "reportDescriptionRemarksPrompt",
        )
        in enabled
    )
    assert (
        configuration.text(
            language,
            "reportDescriptionRemarksPrompt",
        )
        not in disabled
    )
    payload = examination.model_dump(
        mode="json",
    )
    payload.pop(
        "isPatientPreparedForExamination",
    )
    with pytest.raises(
        ValidationError,
    ):
        USExaminationData.model_validate(
            payload,
        )


def test_readiness_does_not_become_an_ultrasound_finding() -> None:
    text = "Описание исследования: стенка ровная. Пациент не подготовлен к исследованию."
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            text,
        ),
    ).validate(
        USVoiceFormGeneration.model_validate(
            [],
        ),
        text,
    )
    values = {p.fieldId: p.value for p in response.proposals}
    assert values[USVoiceFieldId.EXAMINATION_DESCRIPTION] == "стенка ровная."
    assert values[USVoiceFieldId.IS_PATIENT_PREPARED_FOR_EXAMINATION] == "false"
    assert [p.fieldId for p in response.proposals][-2:] == [
        USVoiceFieldId.EXAMINATION_DESCRIPTION,
        USVoiceFieldId.IS_PATIENT_PREPARED_FOR_EXAMINATION,
    ]
