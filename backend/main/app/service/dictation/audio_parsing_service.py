from __future__ import annotations

from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.model.ultrasound.us_audio_parse_request import USAudioParseRequest
from app.model.ultrasound.us_audio_parse_response import USAudioParseResponse
from app.model.ultrasound.us_voice_form_parse_request import USVoiceFormParseRequest
from app.service.dictation.transcript_parsing_service import TranscriptParsingService
from app.service.speech.t_one_transcription_service import TOneTranscriptionService


class AudioParsingService:
    def __init__(
        self,
        configuration: Configuration,
        speech_service: TOneTranscriptionService,
        parser_service: TranscriptParsingService,
    ) -> None:
        self._configuration = configuration
        self._speech_service = speech_service
        self._parser_service = parser_service

    async def parse(
        self,
        audio: bytes,
        parameters: USAudioParseRequest,
        *,
        language: LanguageCode,
        content_type: str | None,
        app_check_token: str | None = None,
        request_id: str | None = None,
    ) -> USAudioParseResponse:
        # Reject unknown context before allocating CPU time for recognition.
        self._configuration.resolve_neural_model(
            parameters.selectedNeuralModelId,
        )
        self._configuration.resolve_examination_title(
            parameters.usExaminationTypeId,
            language,
        )
        transcription_response = await self._speech_service.transcribe(
            audio,
            language=language,
            content_type=content_type,
        )
        result = await self._parser_service.parse(
            USVoiceFormParseRequest(
                selectedNeuralModelId=parameters.selectedNeuralModelId,
                usExaminationTypeId=parameters.usExaminationTypeId,
                transcript=transcription_response.transcript,
            ),
            language=language,
            app_check_token=app_check_token,
            request_id=request_id,
        )
        return USAudioParseResponse(
            transcript=transcription_response.transcript,
            result=result,
        )
