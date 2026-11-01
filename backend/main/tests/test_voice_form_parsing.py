from __future__ import annotations

# ruff: noqa: RUF001
import asyncio
import json
from types import SimpleNamespace
from typing import Any

import pytest
from starlette.requests import Request

from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.core.localization.language_code import LanguageCode
from app.error import ApiError
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.model.ultrasound.us_voice_form_parse_request import USVoiceFormParseRequest
from app.service.dictation.dictation_parsing_service import DictationParsingService
from app.service.dictation.voice_form_validator import VoiceFormValidator
from tests.support.voice_form_parsing.fake_neural_model_service import FakeNeuralModelService
from tests.support.voice_form_parsing.voice_source_localization_test_support import (
    voice_source_localization_test_support,
)

_CONFIG_DIR = Variables(
    environment="development",
).configuration_directory
_CONFIG_BASE = _CONFIG_DIR.parent


def test_voice_parsing_config_loads_for_both_environments(
    configuration: Configuration,
) -> None:
    from app.model.ultrasound.us_voice_form_parsing_config import USVoiceFormParsingConfig

    for environment in ("development", "production"):
        config = USVoiceFormParsingConfig.model_validate(
            json.loads(
                (_CONFIG_BASE / environment / "server.json").read_text(
                    encoding="utf-8",
                ),
            )["voice_form_parsing"],
        )
        assert config.maxTokens == 2048
    assert configuration.server.voice_form_parsing.maxTokens == 2048


def test_validator_returns_sparse_supported_fields_and_rejects_bad_quotes() -> None:
    transcript = "Пациент Иванов Иван. Вес семьдесят два килограмма."
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_name", "value": "Иванов Иван", "evidence": "Пациент Иванов Иван", "accuracy": "full"},
            {
                "field_id": "patient_weight_kg",
                "value": 72,
                "evidence": "Вес семьдесят два килограмма",
                "accuracy": "full",
            },
            {"field_id": "patient_height_cm", "value": 180, "evidence": "рост сто восемьдесят", "accuracy": "full"},
        ],
    )

    response = VoiceFormValidator(
        voice_source_localization_test_support(
            transcript,
        ),
    ).validate(
        generated,
        transcript,
    )

    assert [item.fieldId.value for item in response.proposals] == ["patient_name", "patient_weight_kg"]
    assert [item.value for item in response.proposals] == ["Иванов Иван", 72]
    assert all(
        (item.fieldId.value != "patient_height_cm" for item in response.proposals),
    )


def test_validator_rejects_duplicate_field_without_choosing_one() -> None:
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_gender", "value": "male", "evidence": "male", "accuracy": "full"},
            {"field_id": "patient_gender", "value": "female", "evidence": "female", "accuracy": "full"},
        ],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            "male or female",
        ),
    ).validate(
        generated,
        "male or female",
    )
    assert response.proposals == []
    assert all(
        (item.fieldId.value != "patient_gender" for item in response.proposals),
    )


def test_empty_generation_leaves_form_unchanged() -> None:
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            "Никаких данных формы",
        ),
    ).validate(
        USVoiceFormGeneration.model_validate(
            [],
        ),
        "Никаких данных формы",
    )
    assert response.proposals == []


def test_questionable_accuracy_survives_validation() -> None:
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "patient_name", "value": "Иванов", "evidence": "пациент Иванов", "accuracy": "questionable"}],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            "пациент Иванов",
        ),
    ).validate(
        generated,
        "пациент Иванов",
    )
    assert response.proposals[0].accuracy.value == "questionable"


@pytest.mark.parametrize(
    "transcript,evidence,value",
    [
        (
            "Examination description: left ventricle: fifty two millimeters.",
            "left ventricle: fifty two millimeters",
            "52",
        ),
        ("Описание исследования: правый желудочек 37 мм.", "правый желудочек 37 мм", "37"),
        ("Описание исследования: объём 80 мл.", "объём 80 мл", "80"),
        ("Номер исследования: 007. Описание исследования: желудочек 37 мм.", "желудочек 37 мм", "37"),
        ("Описание исследования: желудочек 37.", "желудочек 37", "37"),
        (
            "Номер исследования: 007. Описание исследования: желудочек 37 мм.",
            "Номер исследования: 007. Описание исследования: желудочек 37 мм.",
            "37",
        ),
    ],
)
def test_measurement_cannot_be_used_as_examination_number(
    transcript: str,
    evidence: str,
    value: str,
) -> None:
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "examination_number", "value": value, "evidence": evidence, "accuracy": "full"}],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            transcript,
        ),
    ).validate(
        generated,
        transcript,
    )
    numbers = [item for item in response.proposals if item.fieldId.value == "examination_number"]
    assert all(
        (item.value != value for item in numbers),
    )


@pytest.mark.parametrize(
    "transcript,evidence,value",
    [
        ("Номер исследования: 007. Описание исследования: желудочек 37 мм.", "007", "007"),
        ("Это исследование номер ноль ноль семь.", "исследование номер ноль ноль семь", "007"),
        ("This is study zero zero seven. No complaints.", "This is study zero zero seven", "007"),
        ("Study ID: A-007.", "A-007", "A-007"),
        ("Exam No. 007.", "Exam No. 007", "007"),
        ("Examination number: zero zero seven.", "zero zero seven", "007"),
        (
            "Описание исследования: желудочек 37 мм. Вес: 82 кг. "
            "Номер исследования: ноль ноль семь. Жалобы: жалоб нет.",
            "Описание исследования: желудочек 37 мм. Вес: 82 кг. "
            "Номер исследования: ноль ноль семь. Жалобы: жалоб нет.",
            "007",
        ),
        (
            "Это исследование номер ноль ноль семь; сообщает: жалоб нет, вес 82 килограмма.",
            "Это исследование номер ноль ноль семь; сообщает: жалоб нет, вес 82 килограмма.",
            "007",
        ),
    ],
)
def test_explicit_study_identifier_is_kept(
    transcript: str,
    evidence: str,
    value: str,
) -> None:
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "examination_number", "value": value, "evidence": evidence, "accuracy": "full"}],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            transcript,
        ),
    ).validate(
        generated,
        transcript,
    )

    assert response.proposals[0].value == value


def test_full_clinical_text_is_preserved_in_response() -> None:
    description = "Правый желудочек: 37 мм. Дополнительных изменений не выявлено. Выпота нет."
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_complaints", "value": "Жалоб нет", "evidence": "Жалоб нет", "accuracy": "full"},
            {"field_id": "examination_description", "value": description, "evidence": description, "accuracy": "full"},
        ],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            f"Жалобы: Жалоб нет. Описание исследования: {description}",
        ),
    ).validate(
        generated,
        f"Жалобы: Жалоб нет. Описание исследования: {description}",
    )
    assert [item.value for item in response.proposals] == ["Жалоб нет", description]


@pytest.mark.parametrize(
    "transcript,complaints,description",
    [
        (
            "Жалобы: Жалоб нет. Описание исследования: Правый желудочек: 37 мм. "
            "Дополнительных изменений не выявлено. Выпота нет.",
            "Жалоб нет.",
            "Правый желудочек: 37 мм. Дополнительных изменений не выявлено. Выпота нет.",
        ),
        (
            "Complaints: No complaints. Examination description: Right ventricle: 37 mm. "
            "No additional abnormality. No effusion.",
            "No complaints.",
            "Right ventricle: 37 mm. No additional abnormality. No effusion.",
        ),
    ],
)
def test_labeled_clinical_sections_survive_model_omission(
    transcript: str,
    complaints: str,
    description: str,
) -> None:
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            transcript,
        ),
    ).validate(
        USVoiceFormGeneration.model_validate(
            [],
        ),
        transcript,
    )
    actual = {item.fieldId.value: item for item in response.proposals}
    assert set(
        actual,
    ) == {"patient_complaints", "examination_description"}
    assert actual["patient_complaints"].value == complaints
    assert actual["examination_description"].value == description
    assert description in actual["examination_description"].evidence
    assert all(
        (item.accuracy.value == "full" for item in actual.values()),
    )


def test_shortened_model_values_are_retained_for_review_without_affecting_other_fields() -> None:
    description = "Правый желудочек: 37 мм. Дополнительных изменений не выявлено."
    transcript = f"Описание исследования: {description} Вес: 82 кг. Жалобы: Жалоб нет. Пациент: Иванов Иван."
    generated = USVoiceFormGeneration.model_validate(
        [
            {
                "field_id": "examination_description",
                "value": "Правый желудочек: 37 мм.",
                "evidence": "Правый желудочек: 37 мм.",
                "accuracy": "full",
            },
            {"field_id": "patient_complaints", "value": "нет", "evidence": "Жалоб нет", "accuracy": "full"},
            {"field_id": "patient_weight_kg", "value": 82, "evidence": "Вес: 82 кг.", "accuracy": "full"},
        ],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            transcript,
        ),
    ).validate(
        generated,
        transcript,
    )
    actual = {item.fieldId.value: item.value for item in response.proposals}
    assert actual == {
        "examination_description": "Правый желудочек: 37 мм.",
        "patient_complaints": "нет",
        "patient_weight_kg": 82,
    }
    assert all(
        (
            item.accuracy.value == "questionable"
            for item in response.proposals
            if isinstance(
                item.value,
                str,
            )
        ),
    )


def test_repeated_clinical_labels_are_not_chosen_automatically() -> None:
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            "Жалобы: боль справа. Жалобы: боли нет.",
        ),
    ).validate(
        USVoiceFormGeneration.model_validate(
            [],
        ),
        "Жалобы: боль справа. Жалобы: боли нет.",
    )
    assert response.proposals == []


def test_free_speech_with_later_explicit_labels_preserves_the_sections() -> None:
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            "На приёме Иванов. Жалобы: боль справа. Описание исследования: печень не увеличена.",
        ),
    ).validate(
        USVoiceFormGeneration.model_validate(
            [],
        ),
        "На приёме Иванов. Жалобы: боль справа. Описание исследования: печень не увеличена.",
    )
    assert {item.fieldId.value: item.value for item in response.proposals} == {
        "patient_complaints": "боль справа.",
        "examination_description": "печень не увеличена.",
    }


def test_natural_ultrasound_cue_marks_model_omissions_for_review() -> None:
    generated = USVoiceFormGeneration.model_validate(
        [
            {
                "field_id": "examination_description",
                "value": "Печень не увеличена.",
                "evidence": "Печень не увеличена.",
                "accuracy": "full",
            }
        ],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            "На УЗИ: Печень не увеличена. Очаговых изменений нет.",
        ),
    ).validate(
        generated,
        "На УЗИ: Печень не увеличена. Очаговых изменений нет.",
    )
    assert response.proposals[0].value == "Печень не увеличена."
    assert response.proposals[0].accuracy.value == "questionable"
    assert response.proposals[0].accuracy.value == "questionable"


def test_explicit_numeric_self_correction_keeps_the_model_normalization() -> None:
    source = "Левый желудочек: 54, нет, 51 мм. Дополнительных изменений не выявлено."
    value = "Левый желудочек: 51 мм. Дополнительных изменений не выявлено."
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "examination_description", "value": value, "evidence": source, "accuracy": "questionable"}],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            f"Жалобы: Жалоб нет. Описание исследования: {source}",
        ),
    ).validate(
        generated,
        f"Жалобы: Жалоб нет. Описание исследования: {source}",
    )
    proposal = next(
        (item for item in response.proposals if item.fieldId.value == "examination_description"),
    )
    assert proposal.value == value
    assert source in proposal.evidence
    assert proposal.accuracy.value == "questionable"


@pytest.mark.parametrize(
    "source",
    ["1 августа 1978 года", "первое августа тысяча девятьсот семьдесят восьмого года"],
)
def test_natural_birth_date_proposal_is_accepted(
    source: str,
) -> None:
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "patient_date_of_birth", "value": "1978-08-01", "evidence": source, "accuracy": "full"}],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            f"Дата рождения: {source}.",
        ),
    ).validate(
        generated,
        f"Дата рождения: {source}.",
    )
    assert response.proposals[0].value == "1978-08-01"
    assert response.proposals[0].accuracy.value == "full"


def test_iso_birth_date_does_not_need_model_conversion() -> None:
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "patient_date_of_birth", "value": "1978-08-01", "evidence": "1978-08-01", "accuracy": "full"}],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            "Дата рождения: 1978-08-01.",
        ),
    ).validate(
        generated,
        "Дата рождения: 1978-08-01.",
    )
    assert response.proposals[0].accuracy.value == "full"


def test_boolean_measurement_is_not_accepted_as_one() -> None:
    with pytest.raises(
        ValueError,
    ):
        USVoiceFormGeneration.model_validate(
            [{"field_id": "patient_weight_kg", "value": True, "evidence": "вес", "accuracy": "full"}],
        )


def test_string_measurement_is_rejected_by_generation_contract() -> None:
    with pytest.raises(
        ValueError,
    ):
        USVoiceFormGeneration.model_validate(
            [{"field_id": "patient_weight_kg", "value": "72", "evidence": "вес 72 кг", "accuracy": "full"}],
        )


def test_generation_schema_caps_repeated_items() -> None:
    schema = USVoiceFormGeneration.model_json_schema()
    assert schema["type"] == "array"
    assert schema["maxItems"] == 8
    variants = [
        schema["$defs"][
            item["$ref"].split(
                "/",
            )[-1]
        ]
        for item in schema["items"]["anyOf"]
    ]
    by_field = {
        field: variant
        for variant in variants
        for field in variant["properties"]["field_id"].get(
            "enum",
            [
                variant["properties"]["field_id"].get(
                    "const",
                )
            ],
        )
    }
    assert by_field["patient_weight_kg"]["properties"]["value"]["type"] == "number"
    assert by_field["patient_height_cm"]["properties"]["value"]["type"] == "number"
    assert by_field["patient_name"]["properties"]["value"]["type"] == "string"
    assert by_field["patient_gender"]["properties"]["value"]["enum"] == ["male", "female"]
    assert by_field["patient_date_of_birth"]["properties"]["value"]["pattern"] == r"^\d{4}-\d{2}-\d{2}$"
    assert all(
        (
            set(
                variant["required"],
            )
            == {"field_id", "value", "evidence", "accuracy"}
            for variant in variants
        ),
    )


def test_selected_report_model_is_used_for_server_parsing(
    configuration: Configuration,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    selected_id = "test/selected-report-model"
    original = configuration.resolve_neural_model(
        "google/medgemma-4b-it",
    )
    model = original.model_copy(
        update={"id": selected_id},
    )

    def resolve(
        model_id: str | None,
    ) -> Any:
        assert model_id == selected_id
        return model

    monkeypatch.setitem(
        configuration.neural_models,
        model.id,
        model,
    )
    service = FakeNeuralModelService(
        [],
    )
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v1/ultrasound/parse_dictation",
            "headers": [],
            "app": SimpleNamespace(
                state=SimpleNamespace(
                    model_service=service,
                ),
            ),
            "state": {"request_id": "e" * 32},
        },
    )
    handler: Any = DictationParsingService(
        configuration,
        request.app.state.model_service,
    ).parse
    asyncio.run(
        handler(
            body=USVoiceFormParseRequest(
                selectedNeuralModelId=selected_id,
                usExaminationTypeId="bladder",
                transcript="Стенка 2 мм.",
            ),
            language=configuration.language(
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
    assert service.request is not None
    assert service.request.model_id == selected_id
    assert service.request.temperature == 0
    assert service.request.max_tokens == 2048


@pytest.mark.parametrize(
    "language,expected_fragment",
    [("en_US", "Extract only"), ("ru_RU", "Извлеки только")],
)
def test_route_sends_text_only_to_gpu_and_returns_checked_proposals(
    configuration: Configuration,
    language: str,
    expected_fragment: str,
) -> None:
    transcript = "weight 72 kilograms" if language == "en_US" else "вес 72 килограмма"
    service = FakeNeuralModelService(
        [{"field_id": "patient_weight_kg", "value": 72, "evidence": transcript, "accuracy": "full"}],
    )
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v1/ultrasound/parse_dictation",
            "headers": [
                (b"accept-language", language.encode()),
                (b"x-firebase-appcheck", b"token"),
            ],
            "app": SimpleNamespace(
                state=SimpleNamespace(
                    model_service=service,
                ),
            ),
            "state": {"request_id": "b" * 32},
        },
    )
    body = USVoiceFormParseRequest(
        usExaminationTypeId="echocardiography",
        transcript=transcript,
    )
    handler: Any = DictationParsingService(
        configuration,
        request.app.state.model_service,
    ).parse

    response = asyncio.run(
        handler(
            body=body,
            language=configuration.language(
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

    assert response.proposals[0].value == 72
    assert service.request is not None
    assert service.request.model_id == "google/medgemma-4b-it"
    assert service.request.max_tokens == 2048
    assert service.request.photos == []
    assert service.request.app_check_token == "token"
    assert service.request.request_id == "b" * 32
    assert (
        json.loads(
            service.request.prompt,
        )["transcript"]
        == body.transcript
    )
    assert json.loads(
        service.request.prompt,
    )["contextualStrings"] == configuration.resolve_examination_contextual_strings(
        body.usExaminationTypeId,
        LanguageCode(
            language[:2],
        ),
    )
    assert (
        json.loads(
            service.request.structured_output,
        )["type"]
        == "array"
    )
    assert expected_fragment in service.request.system_prompt
    assert service.request.system_prompt == (
        configuration.text(
            LanguageCode(
                language[:2],
            ),
            "voiceFormSystemPrompt",
        )
        + " "
        + configuration.text(
            LanguageCode(
                language[:2],
            ),
            "medicalTermCorrectionPrompt",
        )
    )


def test_route_rejects_unknown_examination_type(
    configuration: Configuration,
) -> None:
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v1/ultrasound/parse_dictation",
            "headers": [],
            "app": SimpleNamespace(
                state=SimpleNamespace(
                    model_service=FakeNeuralModelService(
                        {},
                    ),
                ),
            ),
            "state": {"request_id": "c" * 32},
        },
    )
    handler: Any = DictationParsingService(
        configuration,
        request.app.state.model_service,
    ).parse
    with pytest.raises(
        ApiError,
    ) as error:
        asyncio.run(
            handler(
                body=USVoiceFormParseRequest(
                    usExaminationTypeId="unknown",
                    transcript="hello",
                ),
                language=configuration.language(
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
    assert error.value.status_code == 400
