from __future__ import annotations

import asyncio
import multiprocessing
from concurrent.futures import ProcessPoolExecutor
from concurrent.futures.process import BrokenProcessPool
from pathlib import Path

from app.core.localization.language_code import LanguageCode
from app.error.invalid_audio_error import InvalidAudioError
from app.error.no_speech_error import NoSpeechError
from app.error.speech_busy_error import SpeechBusyError
from app.error.speech_unavailable_error import SpeechUnavailableError
from app.model.speech.speech_transcript_response import SpeechTranscriptResponse
from app.model.speech.t_one_config import TOneConfig
from app.service.speech.t_one_worker import TOneWorker


class TOneTranscriptionService:
    # Fixed transport contract shared with DSpeechTOneAudioCapture: five minutes.
    max_audio_bytes = 8000 * 2 * 300

    def __init__(
        self,
        model_path: Path | None,
        config: TOneConfig,
    ) -> None:
        self._model_path = model_path
        self._config = config
        self._executor: ProcessPoolExecutor | None = None
        self._slot = asyncio.Lock()
        self._pending = 0

    async def start(
        self,
    ) -> None:
        if self._model_path is None:
            return
        self._executor = ProcessPoolExecutor(
            max_workers=1,
            mp_context=multiprocessing.get_context(
                "spawn",
            ),
        )
        await asyncio.get_running_loop().run_in_executor(
            self._executor,
            TOneWorker.initialize,
            self._model_path,
            self._config.cpu_threads,
        )

    async def close(
        self,
    ) -> None:
        if self._executor is not None:
            executor, self._executor = self._executor, None
            await asyncio.to_thread(
                executor.shutdown,
                wait=True,
                cancel_futures=True,
            )

    async def transcribe(
        self,
        audio: bytes,
        *,
        language: LanguageCode,
        content_type: str | None,
    ) -> SpeechTranscriptResponse:
        if (
            language != LanguageCode.RU
            or content_type != "application/octet-stream"
            or not audio
            or len(
                audio,
            )
            % 2
            or len(
                audio,
            )
            > self.max_audio_bytes
        ):
            raise InvalidAudioError()
        if self._executor is None:
            raise SpeechUnavailableError()
        if self._pending >= 1 + self._config.max_waiting_requests:
            raise SpeechBusyError()
        self._pending += 1
        try:
            await asyncio.wait_for(
                self._slot.acquire(),
                self._config.queue_timeout_seconds,
            )
        except TimeoutError as error:
            self._pending -= 1
            raise SpeechBusyError() from error
        except BaseException:
            self._pending -= 1
            raise
        if self._executor is None:
            self._slot.release()
            self._pending -= 1
            raise SpeechUnavailableError()
        try:
            future = asyncio.get_running_loop().run_in_executor(
                self._executor,
                TOneWorker.transcribe,
                audio,
            )
        except (BrokenProcessPool, RuntimeError) as error:
            self._slot.release()
            self._pending -= 1
            raise SpeechUnavailableError() from error
        # Cancellation/HTTP timeout does not stop a CPU job. Hold capacity until
        # the actual work ends; otherwise retries accumulate unbounded jobs.
        future.add_done_callback(
            self._release_slot,
        )
        try:
            transcript = await asyncio.wait_for(
                asyncio.shield(
                    future,
                ),
                self._config.operation_timeout_seconds,
            )
        except TimeoutError as error:
            raise SpeechUnavailableError() from error
        except Exception as error:
            raise SpeechUnavailableError() from error
        if not transcript.strip():
            raise NoSpeechError()
        return SpeechTranscriptResponse(
            transcript=transcript,
        )

    def _release_slot(
        self,
        future: asyncio.Future[str],
    ) -> None:
        self._pending -= 1
        self._slot.release()
        if not future.cancelled():
            future.exception()
