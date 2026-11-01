from __future__ import annotations

import asyncio
import json
from types import SimpleNamespace
from typing import Any

import pytest
from starlette.requests import Request

from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.core.localization.language_code import LanguageCode
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


@pytest.mark.parametrize(
    "language,raw,corrected",
    [
        (LanguageCode.RU, "содержимое анофагенное", "Содержимое анэхогенное."),
        (LanguageCode.EN, "anechoeic contents", "Anechoic contents."),
        (LanguageCode.RU, "эхагенная взвесь", "Эхогенная взвесь."),
        (LanguageCode.EN, "mural lezhion", "Mural lesion."),
    ],
)
def test_route_sends_selected_vocabulary_and_retains_corrected_value_with_verbatim_evidence(
    configuration: Configuration,
    language: LanguageCode,
    raw: str,
    corrected: str,
) -> None:
    service = FakeNeuralModelService(
        [{"field_id": "examination_description", "value": corrected, "evidence": raw, "accuracy": "full"}],
    )
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v1/ultrasound/parse_dictation",
            "headers": [(b"accept-language", language.value.encode())],
            "app": SimpleNamespace(
                state=SimpleNamespace(
                    model_service=service,
                ),
            ),
            "state": {"request_id": "d" * 32},
        },
    )
    handler: Any = DictationParsingService(
        configuration,
        request.app.state.model_service,
    ).parse
    response = asyncio.run(
        handler(
            body=USVoiceFormParseRequest(
                usExaminationTypeId="bladder",
                transcript=raw,
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
    prompt = json.loads(
        service.request.prompt,
    )
    assert prompt["contextualStrings"] == configuration.resolve_examination_contextual_strings(
        "bladder",
        language,
    )
    assert prompt["contextualStrings"] != configuration.resolve_examination_contextual_strings(
        "thyroidGland",
        language,
    )
    assert prompt["transcript"] == raw
    assert "contextualStrings" in service.request.system_prompt
    assert response.proposals[0].value == corrected
    assert response.proposals[0].evidence == raw
    assert response.proposals[0].accuracy.value == "questionable"


def test_labeled_source_does_not_override_a_model_term_correction() -> None:
    raw = "содержимое анофагенное стенка 2,3 мм включений нет"
    corrected = "Содержимое анэхогенное. Стенка 2,3 мм. Включений нет."
    transcript = f"Жалобы: жалоб нет. Описание исследования: {raw}"
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "examination_description", "value": corrected, "evidence": raw, "accuracy": "full"}],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            transcript,
        ),
    ).validate(
        generated,
        transcript,
    )
    fields = {item.fieldId.value: item for item in response.proposals}
    assert fields["examination_description"].value == corrected
    assert fields["examination_description"].accuracy.value == "questionable"
    assert fields["examination_description"].evidence == raw
    assert fields["patient_complaints"].value == "жалоб нет."
    assert fields["patient_complaints"].accuracy.value == "full"


@pytest.mark.parametrize(
    "corrected",
    [
        "Содержимое анэхогенное слева. Стенка 2,4 мм. Включений нет.",
        "Содержимое анэхогенное справа. Стенка 2,3 мм. Включений нет.",
        "Содержимое анэхогенное слева. Стенка 2,3 см. Включений нет.",
        "Содержимое анэхогенное слева. Стенка 2,3 мм. Включения есть.",
        "Содержимое анэхогенное слева. Стенка 2,3 мм.",
        "Содержимое анэхогенное слева. Включений нет. Стенка 2,3 мм.",
        "Содержимое анэхогенное слева. Стенка 2,3 мм. Включений нет. Контуры ровные.",
        "Содержимое гипоэхогенное слева. Стенка 2,3 мм. Включений нет.",
    ],
)
def test_every_clinical_difference_remains_visible_for_physician_review(
    corrected: str,
) -> None:
    raw = "содержимое анофагенное слева стенка 2,3 мм включений нет"
    transcript = f"Жалобы: жалоб нет. Описание исследования: {raw}"
    generated = USVoiceFormGeneration.model_validate(
        [{"field_id": "examination_description", "value": corrected, "evidence": raw, "accuracy": "full"}],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            transcript,
        ),
    ).validate(
        generated,
        transcript,
    )
    field = next(
        (item for item in response.proposals if item.fieldId.value == "examination_description"),
    )
    assert field.value == corrected
    assert field.evidence == raw
    assert field.accuracy.value == "questionable"


def test_a_new_model_correction_does_not_require_a_predefined_pair() -> None:
    raw = "содержимое анофагенное"
    generated = USVoiceFormGeneration.model_validate(
        [
            {
                "field_id": "examination_description",
                "value": "содержимое анэхогенное",
                "evidence": raw,
                "accuracy": "full",
            }
        ],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            raw,
        ),
    ).validate(
        generated,
        raw,
    )
    assert response.proposals[0].value == "содержимое анэхогенное"
    assert response.proposals[0].accuracy.value == "questionable"


def test_generated_canonical_evidence_cannot_replace_the_actual_transcript() -> None:
    raw = "содержимое анофагенное"
    generated = USVoiceFormGeneration.model_validate(
        [
            {
                "field_id": "examination_description",
                "value": "содержимое анэхогенное",
                "evidence": "содержимое анэхогенное",
                "accuracy": "full",
            }
        ],
    )
    response = VoiceFormValidator(
        voice_source_localization_test_support(
            raw,
        ),
    ).validate(
        generated,
        "Жалобы: жалоб нет. Описание исследования: " + raw,
    )
    assert (
        next(
            (item.value for item in response.proposals if item.fieldId.value == "examination_description"),
        )
        == raw
    )
