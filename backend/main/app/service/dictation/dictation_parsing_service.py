from __future__ import annotations

import logging

from pydantic import ValidationError

from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.error import InvalidDictationResponseError
from app.model.neural_model.neural_model_service_operation import NeuralModelServiceOperation
from app.model.neural_model.neural_model_service_request import NeuralModelServiceRequest
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.model.ultrasound.us_voice_form_parse_request import USVoiceFormParseRequest
from app.model.ultrasound.us_voice_form_parse_response import USVoiceFormParseResponse
from app.prompt.prompt_factory import PromptFactory
from app.service.dictation.voice_form_validator import VoiceFormValidator
from app.service.neural_model.neural_model_service import NeuralModelService
from app.service.validation.text_length_validator import TextLengthValidator

logger = logging.getLogger(
    __name__,
)


class DictationParsingService:
    def __init__(
        self,
        configuration: Configuration,
        model_service: NeuralModelService,
    ) -> None:
        self._configuration = configuration
        self._model_service = model_service

    async def parse(
        self,
        body: USVoiceFormParseRequest,
        *,
        language: LanguageCode,
        app_check_token: str | None = None,
        request_id: str | None = None,
    ) -> USVoiceFormParseResponse:
        TextLengthValidator.validate(
            body.transcript,
            self._configuration.modules.scanSpeech.transcriptMaxLength,
            ["body", "transcript"],
        )
        prompt_factory = PromptFactory(
            language,
            self._configuration,
        )
        title = self._configuration.resolve_examination_title(
            body.usExaminationTypeId,
            language,
        )
        contextual_strings = self._configuration.resolve_examination_contextual_strings(
            body.usExaminationTypeId,
            language,
        )
        config = self._configuration.server.voice_form_parsing
        model = self._configuration.resolve_neural_model(
            body.selectedNeuralModelId,
        )
        logger.info(
            "Voice parse request: model=%s, language=%s, examination_type=%s, transcript_chars=%d",
            model.id,
            language.value,
            body.usExaminationTypeId,
            len(
                body.transcript,
            ),
        )

        response_text = await self._model_service.call(
            NeuralModelServiceRequest(
                operation=NeuralModelServiceOperation.PARSE_DICTATION,
                language_code=language,
                model_id=model.id,
                system_prompt=prompt_factory.voice_system_prompt(),
                prompt=prompt_factory.voice_prompt(
                    title,
                    body.transcript,
                    contextual_strings,
                ),
                structured_output=USVoiceFormGeneration.structured_output(),
                temperature=0,
                max_tokens=config.maxTokens,
                app_check_token=app_check_token,
                request_id=request_id,
            ),
        )
        try:
            generated = USVoiceFormGeneration.model_validate_json(
                response_text,
            )
        except ValidationError as error:
            raise InvalidDictationResponseError() from error
        return VoiceFormValidator(
            self._configuration.voice_source_localization(
                language,
            ),
        ).validate(
            generated,
            body.transcript,
        )
