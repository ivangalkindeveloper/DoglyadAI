from __future__ import annotations

# ruff: noqa: RUF001
import asyncio
import inspect
import json
from types import SimpleNamespace
from typing import Any

import pytest
from fastapi import HTTPException
from starlette.requests import Request

from app.core.config import load_configs
from app.model.inference.inference_request import InferenceRequest
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.model.ultrasound.us_voice_form_parse_request import USVoiceFormParseRequest
from app.route.ultrasound import parse_dictation as route
from app.service.voice_form_validation import validate_voice_form_generation


def test_voice_parsing_config_loads_for_both_environments() -> None:
    from app.core.config import _CONFIG_BASE, get_voice_parsing_config
    from app.model.ultrasound.us_voice_form_parsing_config import USVoiceFormParsingConfig

    for environment in ("development", "production"):
        config = USVoiceFormParsingConfig.model_validate_json(
            (_CONFIG_BASE / environment / "voice_form_parsing.json").read_text(encoding="utf-8")
        )
        assert config.modelId == "google/medgemma-4b-it"
    load_configs()
    assert get_voice_parsing_config().maxTokens == 2048


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
        ]
    )

    response = validate_voice_form_generation(generated, transcript)

    assert [item.field_id.value for item in response.proposals] == ["patient_name", "patient_weight_kg"]
    assert [item.value for item in response.proposals] == ["Иванов Иван", 72]
    assert [item.value for item in response.rejectedFieldIds] == ["patient_height_cm"]
    assert response.unmappedFindings == []


def test_validator_rejects_duplicate_field_without_choosing_one() -> None:
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_gender", "value": "male", "evidence": "male", "accuracy": "full"},
            {"field_id": "patient_gender", "value": "female", "evidence": "female", "accuracy": "full"},
        ]
    )
    response = validate_voice_form_generation(generated, "male or female")
    assert response.proposals == []
    assert [item.value for item in response.rejectedFieldIds] == ["patient_gender"]


def test_empty_generation_leaves_form_unchanged() -> None:
    response = validate_voice_form_generation(USVoiceFormGeneration.model_validate([]), "Никаких данных формы")
    assert response.proposals == []
    assert response.rejectedFieldIds == []


def test_questionable_accuracy_survives_validation() -> None:
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "patient_name", "value": "Иванов", "evidence": "пациент Иванов", "accuracy": "questionable"}]
    )
    response = validate_voice_form_generation(generated, "пациент Иванов")
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
def test_measurement_cannot_be_used_as_examination_number(transcript: str, evidence: str, value: str) -> None:
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "examination_number", "value": value, "evidence": evidence, "accuracy": "full"}]
    )
    response = validate_voice_form_generation(generated, transcript)
    numbers = [item for item in response.proposals if item.field_id.value == "examination_number"]
    assert all(item.value != value for item in numbers)
    if not numbers:
        assert [item.value for item in response.rejectedFieldIds] == ["examination_number"]


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
def test_explicit_study_identifier_is_kept(transcript: str, evidence: str, value: str) -> None:
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "examination_number", "value": value, "evidence": evidence, "accuracy": "full"}]
    )
    response = validate_voice_form_generation(generated, transcript)
    assert response.rejectedFieldIds == []
    assert response.proposals[0].value == value


def test_full_clinical_text_is_preserved_in_response() -> None:
    description = "Правый желудочек: 37 мм. Дополнительных изменений не выявлено. Выпота нет."
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_complaints", "value": "Жалоб нет", "evidence": "Жалоб нет", "accuracy": "full"},
            {"field_id": "examination_description", "value": description, "evidence": description, "accuracy": "full"},
        ]
    )
    response = validate_voice_form_generation(generated, f"Жалобы: Жалоб нет. Описание исследования: {description}")
    assert [item.value for item in response.proposals] == ["Жалоб нет.", description]


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
def test_labeled_clinical_sections_survive_model_omission(transcript: str, complaints: str, description: str) -> None:
    response = validate_voice_form_generation(USVoiceFormGeneration.model_validate([]), transcript)
    actual = {item.field_id.value: item for item in response.proposals}
    assert set(actual) == {"patient_complaints", "examination_description"}
    assert actual["patient_complaints"].value == complaints
    assert actual["examination_description"].value == description
    assert description in actual["examination_description"].evidence
    assert all(item.accuracy.value == "full" for item in actual.values())
    assert response.rejectedFieldIds == []


def test_labeled_text_replaces_shortening_and_stops_before_other_fields() -> None:
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
        ]
    )
    response = validate_voice_form_generation(generated, transcript)
    actual = {item.field_id.value: item.value for item in response.proposals}
    assert actual == {
        "examination_description": description,
        "patient_complaints": "Жалоб нет.",
        "patient_weight_kg": 82,
    }


def test_repeated_clinical_labels_are_not_chosen_automatically() -> None:
    response = validate_voice_form_generation(
        USVoiceFormGeneration.model_validate([]), "Жалобы: боль справа. Жалобы: боли нет."
    )
    assert response.proposals == []


def test_free_speech_with_later_explicit_labels_preserves_the_sections() -> None:
    response = validate_voice_form_generation(
        USVoiceFormGeneration.model_validate([]),
        "На приёме Иванов. Жалобы: боль справа. Описание исследования: печень не увеличена.",
    )
    assert {item.field_id.value: item.value for item in response.proposals} == {
        "patient_complaints": "боль справа.",
        "examination_description": "печень не увеличена.",
    }


def test_natural_ultrasound_cue_restores_sentences_omitted_by_the_model() -> None:
    generated = USVoiceFormGeneration.model_validate(
        [
            {
                "field_id": "examination_description",
                "value": "Печень не увеличена.",
                "evidence": "Печень не увеличена.",
                "accuracy": "full",
            }
        ]
    )
    response = validate_voice_form_generation(generated, "На УЗИ: Печень не увеличена. Очаговых изменений нет.")
    assert response.proposals[0].value == "Печень не увеличена. Очаговых изменений нет."
    assert response.proposals[0].accuracy.value == "questionable"


def test_explicit_numeric_self_correction_keeps_the_model_normalization() -> None:
    source = "Левый желудочек: 54, нет, 51 мм. Дополнительных изменений не выявлено."
    value = "Левый желудочек: 51 мм. Дополнительных изменений не выявлено."
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "examination_description", "value": value, "evidence": source, "accuracy": "questionable"}]
    )
    response = validate_voice_form_generation(generated, f"Жалобы: Жалоб нет. Описание исследования: {source}")
    proposal = next(item for item in response.proposals if item.field_id.value == "examination_description")
    assert proposal.value == value
    assert source in proposal.evidence
    assert proposal.accuracy.value == "questionable"


@pytest.mark.parametrize(
    "source",
    ["1 августа 1978 года", "первое августа тысяча девятьсот семьдесят восьмого года"],
)
def test_natural_birth_date_proposal_is_accepted(source: str) -> None:
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "patient_date_of_birth", "value": "1978-08-01", "evidence": source, "accuracy": "full"}]
    )
    response = validate_voice_form_generation(generated, f"Дата рождения: {source}.")
    assert response.proposals[0].value == "1978-08-01"
    assert response.proposals[0].accuracy.value == "full"


def test_iso_birth_date_does_not_need_model_conversion() -> None:
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "patient_date_of_birth", "value": "1978-08-01", "evidence": "1978-08-01", "accuracy": "full"}]
    )
    response = validate_voice_form_generation(generated, "Дата рождения: 1978-08-01.")
    assert response.proposals[0].accuracy.value == "full"


def test_boolean_measurement_is_not_accepted_as_one() -> None:
    with pytest.raises(ValueError):
        USVoiceFormGeneration.model_validate(
            [{"field_id": "patient_weight_kg", "value": True, "evidence": "вес", "accuracy": "full"}]
        )


def test_string_measurement_is_rejected_by_generation_contract() -> None:
    with pytest.raises(ValueError):
        USVoiceFormGeneration.model_validate(
            [{"field_id": "patient_weight_kg", "value": "72", "evidence": "вес 72 кг", "accuracy": "full"}]
        )


def test_generation_schema_caps_repeated_items() -> None:
    schema = USVoiceFormGeneration.model_json_schema()
    assert schema["type"] == "array"
    assert schema["maxItems"] == 8
    variants = [schema["$defs"][item["$ref"].split("/")[-1]] for item in schema["items"]["anyOf"]]
    by_field = {field: variant for variant in variants for field in variant["properties"]["field_id"]["enum"]}
    assert by_field["patient_weight_kg"]["properties"]["value"]["type"] == "number"
    assert by_field["patient_height_cm"]["properties"]["value"]["type"] == "number"
    assert by_field["patient_name"]["properties"]["value"]["type"] == "string"
    assert all(set(variant["required"]) == {"field_id", "value", "evidence", "accuracy"} for variant in variants)


class FakeModelService:
    def __init__(self, response: Any) -> None:
        self.response = response
        self.request: InferenceRequest | None = None

    async def call(self, request: InferenceRequest) -> str:
        self.request = request
        return json.dumps(self.response, ensure_ascii=False)


@pytest.mark.parametrize("language,expected_fragment", [("en_US", "Extract only"), ("ru_RU", "Извлеки только")])
def test_route_sends_text_only_to_gpu_and_returns_checked_proposals(language: str, expected_fragment: str) -> None:
    load_configs()
    service = FakeModelService(
        [{"field_id": "patient_weight_kg", "value": 72, "evidence": "вес 72 килограмма", "accuracy": "full"}]
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
            "app": SimpleNamespace(state=SimpleNamespace(model_service=service)),
            "state": {"request_id": "b" * 32},
        }
    )
    body = USVoiceFormParseRequest(
        usExaminationTypeId="echocardiography",
        transcript="вес 72 килограмма",
    )
    handler: Any = inspect.unwrap(route.parse_dictation)

    response = asyncio.run(handler(body=body, request=request))

    assert response.proposals[0].value == 72
    assert service.request is not None
    assert service.request.model_id == "google/medgemma-4b-it"
    assert service.request.max_tokens == 2048
    assert service.request.photos == []
    assert service.request.app_check_token == "token"
    assert service.request.request_id == "b" * 32
    assert json.loads(service.request.prompt)["transcript"] == body.transcript
    assert json.loads(service.request.structured_output)["type"] == "array"
    assert expected_fragment in service.request.system_prompt


def test_route_rejects_unknown_examination_type() -> None:
    load_configs()
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v1/ultrasound/parse_dictation",
            "headers": [],
            "app": SimpleNamespace(state=SimpleNamespace(model_service=FakeModelService({}))),
            "state": {"request_id": "c" * 32},
        }
    )
    handler: Any = inspect.unwrap(route.parse_dictation)
    with pytest.raises(HTTPException) as error:
        asyncio.run(
            handler(
                body=USVoiceFormParseRequest(usExaminationTypeId="unknown", transcript="hello"),
                request=request,
            )
        )
    assert error.value.status_code == 400
