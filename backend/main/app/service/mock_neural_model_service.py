from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import assert_never

from app.core.language_code import LanguageCode
from app.model.mock.mock_report_fixture import MockReportFixture
from app.model.mock.mock_voice_form_fixture import MockVoiceFormFixture
from app.model.neural_model.neural_model_service_operation import NeuralModelServiceOperation
from app.model.neural_model.neural_model_service_request import NeuralModelServiceRequest
from app.model.ultrasound.us_examination_photo_remarks import USExaminationPhotoRemarks
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.service.neural_model_service import NeuralModelService

logger = logging.getLogger(__name__)
_FIXTURES_DIR = Path(__file__).resolve().parents[1] / "mock"


class MockNeuralModelService(NeuralModelService):
    """Deterministic local generation; routes still validate the returned content."""

    def __init__(self) -> None:
        try:
            self._reports = {
                language: MockReportFixture.model_validate_json(
                    (_FIXTURES_DIR / language.value / "report.json").read_text(encoding="utf-8")
                )
                for language in LanguageCode
            }
            self._voice_forms = {
                language: MockVoiceFormFixture.model_validate_json(
                    (_FIXTURES_DIR / language.value / "voice_form.json").read_text(encoding="utf-8")
                )
                for language in LanguageCode
            }
        except (OSError, ValueError) as error:
            raise RuntimeError("Failed to load local mock fixtures") from error
        logger.info("Mock model service configured; GPU inference is not used")

    async def call(self, request: NeuralModelServiceRequest) -> str:
        logger.info(
            "Mock generation: operation=%s, model=%s, language=%s, photos=%d",
            request.operation.value,
            request.model_id,
            request.language_code.value,
            len(request.photos),
        )
        match request.operation:
            case NeuralModelServiceOperation.GENERATE_REPORT:
                return self._generate_report(request)
            case NeuralModelServiceOperation.PARSE_DICTATION:
                return self._parse_dictation(request)
        assert_never(request.operation)

    def _generate_report(self, request: NeuralModelServiceRequest) -> str:
        fixture = self._reports[request.language_code]
        properties = json.loads(request.structured_output)["properties"]
        report = fixture.report.model_dump(mode="json", include=set(properties))
        if "photoRemarks" in properties:
            report["photoRemarks"] = [
                USExaminationPhotoRemarks(photoId=photo.id, points=fixture.photoRemarkPoints).model_dump(mode="json")
                for photo in request.photos
            ]
        return json.dumps(report, ensure_ascii=False)

    def _parse_dictation(self, request: NeuralModelServiceRequest) -> str:
        # The voice prompt is a JSON document, not a language-dependent template.
        # Only return fixture fields whose evidence occurs in the actual input.
        transcript: str = json.loads(request.prompt)["transcript"]
        folded_transcript = transcript.casefold()
        fixture = self._voice_forms[request.language_code]
        generation = USVoiceFormGeneration(
            root=[item for item in fixture.generation.root if folded_transcript.count(item.evidence.casefold()) == 1]
        )
        return generation.model_dump_json()
