from __future__ import annotations

import asyncio
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from threading import Event
from unittest.mock import AsyncMock

import httpx
import pytest
from fastapi import FastAPI

from app.core.app_check.app_check import AppCheck
from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.core.localization.language_code import LanguageCode
from app.error.invalid_audio_error import InvalidAudioError
from app.error.no_speech_error import NoSpeechError
from app.error.speech_busy_error import SpeechBusyError
from app.error.speech_unavailable_error import SpeechUnavailableError
from app.model.speech.speech_transcript_response import SpeechTranscriptResponse
from app.model.speech.t_one_config import TOneConfig
from app.service.billing.subscription_service import SubscriptionService
from app.service.dictation.audio_parsing_service import AudioParsingService
from app.service.dictation.transcript_parsing_service import TranscriptParsingService
from app.service.neural_model.neural_model_service import NeuralModelService
from app.service.speech.t_one_transcription_service import TOneTranscriptionService
from app.service.speech.t_one_worker import TOneWorker

_ROUTE = "/v1/ultrasound/parse_audio?usExaminationTypeId=echocardiography&selectedNeuralModelId=google%2Fmedgemma-4b-it"


@pytest.mark.parametrize(
    "model_id",
    [None, "", " "],
)
def test_parsing_endpoints_require_a_nonblank_selected_model(
    app: FastAPI,
    model_id: str | None,
) -> None:
    app.dependency_overrides[AppCheck.verify] = lambda: None
    service = AsyncMock(
        spec=AudioParsingService,
    )
    app.dependency_overrides[ServiceDependencies.audio_parsing] = lambda: service

    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(
                app=app,
            ),
            base_url="http://test",
        ) as client:
            parameters = {"usExaminationTypeId": "echocardiography"}
            if model_id is not None:
                parameters["selectedNeuralModelId"] = model_id
            audio = await client.post(
                "/v1/ultrasound/parse_audio",
                params=parameters,
                content=b"\0\0",
            )
            assert audio.status_code == 422
            text = await client.post(
                "/v1/ultrasound/parse_transcript",
                json={**parameters, "transcript": "test"},
            )
            assert text.status_code == 422
            null_model = await client.post(
                "/v1/ultrasound/parse_transcript",
                json={**parameters, "selectedNeuralModelId": None, "transcript": "test"},
            )
            assert null_model.status_code == 422
            service.parse.assert_not_awaited()

    asyncio.run(
        run(),
    )


def test_audio_route_requires_app_check_and_microphone_entitlement(
    app: FastAPI,
) -> None:
    subscriptions = AsyncMock(
        spec=SubscriptionService,
    )
    app.state.container = replace(
        app.state.container,
        subscription_service=subscriptions,
    )

    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(
                app=app,
            ),
            base_url="http://test",
        ) as client:
            response = await client.post(
                _ROUTE,
                content=b"\x00\x00",
            )
            assert response.status_code == 401
            app.dependency_overrides[AppCheck.verify] = lambda: None
            del app.dependency_overrides[BillingDependencies.dictation_access]
            response = await client.post(
                _ROUTE,
                content=b"\x00\x00",
            )
            assert response.status_code == 401

    asyncio.run(
        run(),
    )


def test_audio_route_contract_and_retired_text_route(
    app: FastAPI,
) -> None:
    service = AsyncMock(
        spec=TOneTranscriptionService,
    )
    service.transcribe.return_value = SpeechTranscriptResponse(
        transcript="test speech",
    )
    app.dependency_overrides[AppCheck.verify] = lambda: None
    app.dependency_overrides[ServiceDependencies.audio_parsing] = lambda: AudioParsingService(
        app.state.container.configuration,
        service,
        app.state.container.transcript_parsing_service,
    )

    model = AsyncMock(
        spec=NeuralModelService,
    )
    model.call.return_value = "[]"
    parser = TranscriptParsingService(
        app.state.container.configuration,
        model,
    )
    app.dependency_overrides[ServiceDependencies.audio_parsing] = lambda: AudioParsingService(
        app.state.container.configuration,
        service,
        parser,
    )

    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(
                app=app,
            ),
            base_url="http://test",
        ) as client:
            response = await client.post(
                _ROUTE,
                content=b"\x00\x00",
                headers={
                    "Content-Type": "application/octet-stream",
                    "Accept-Language": "ru",
                    "X-Firebase-AppCheck": "app-check-token",
                    "X-Request-ID": "audio-request",
                },
            )
            assert response.status_code == 200
            assert response.json() == {"transcript": "test speech", "result": {"proposals": []}}
            model.call.assert_awaited_once()
            request = model.call.call_args.args[0]
            assert request.app_check_token == "app-check-token"
            assert request.request_id == response.headers["X-Request-ID"]
            assert "test speech" in request.prompt
            service.transcribe.assert_awaited_once_with(
                b"\x00\x00",
                language=LanguageCode.RU,
                content_type="application/octet-stream",
            )
            assert (
                await client.post(
                    "/v1/ultrasound/transcribe_audio",
                    json={},
                )
            ).status_code == 404
            assert (
                await client.post(
                    "/v1/ultrasound/parse_transcript",
                    json={},
                )
            ).status_code == 422

    asyncio.run(
        run(),
    )


def test_audio_body_limit_applies_to_chunked_uploads(
    app: FastAPI,
) -> None:
    service = AsyncMock(
        spec=TOneTranscriptionService,
    )
    app.dependency_overrides[AppCheck.verify] = lambda: None
    app.dependency_overrides[ServiceDependencies.audio_parsing] = lambda: AudioParsingService(
        app.state.container.configuration,
        service,
        app.state.container.transcript_parsing_service,
    )

    async def chunks():
        yield b"\x00" * TOneTranscriptionService.max_audio_bytes
        yield b"\x00\x00"

    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(
                app=app,
            ),
            base_url="http://test",
        ) as client:
            response = await client.post(
                _ROUTE,
                content=chunks(),
            )
            assert response.status_code == 413
            service.transcribe.assert_not_called()

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "audio,language,content_type",
    [
        (b"", LanguageCode.RU, "application/octet-stream"),
        (b"\x00", LanguageCode.RU, "application/octet-stream"),
        (b"\x00\x00", LanguageCode.EN, "application/octet-stream"),
        (b"\x00\x00", LanguageCode.RU, "audio/wav"),
    ],
)
def test_invalid_audio_never_enters_cpu_queue(
    audio: bytes,
    language: LanguageCode,
    content_type: str,
) -> None:
    service = TOneTranscriptionService(
        None,
        TOneConfig(),
    )
    with pytest.raises(
        InvalidAudioError,
    ):
        asyncio.run(
            service.transcribe(
                audio,
                language=language,
                content_type=content_type,
            ),
        )


def test_unconfigured_t_one_does_not_download_models() -> None:
    service = TOneTranscriptionService(
        None,
        TOneConfig(),
    )

    async def run() -> None:
        await service.start()
        with pytest.raises(
            SpeechUnavailableError,
        ):
            await service.transcribe(
                b"\x00\x00",
                language=LanguageCode.RU,
                content_type="application/octet-stream",
            )
        await service.close()

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "is_cancelled",
    [False, True],
)
def test_timeout_and_cancellation_hold_capacity_until_cpu_finishes(
    monkeypatch: pytest.MonkeyPatch,
    is_cancelled: bool,
) -> None:
    entered, release = Event(), Event()

    def recognize(
        audio: bytes,
    ) -> str:
        entered.set()
        release.wait(
            5,
        )
        return "test speech"

    monkeypatch.setattr(
        TOneWorker,
        "transcribe",
        recognize,
    )

    async def run() -> None:
        service = TOneTranscriptionService(
            None,
            TOneConfig(
                max_waiting_requests=0,
                operation_timeout_seconds=0.05,
            ),
        )
        # A controlled thread substitutes only the process boundary in this test.
        service._executor = ThreadPoolExecutor(
            max_workers=1,
        )

        async def request():
            return await service.transcribe(
                b"\x00\x00",
                language=LanguageCode.RU,
                content_type="application/octet-stream",
            )

        try:
            task = asyncio.create_task(
                request(),
            )
            assert await asyncio.to_thread(
                entered.wait,
                2,
            )
            if is_cancelled:
                task.cancel()
                with pytest.raises(
                    asyncio.CancelledError,
                ):
                    await task
            else:
                with pytest.raises(
                    SpeechUnavailableError,
                ):
                    await task
            with pytest.raises(
                SpeechBusyError,
            ):
                await request()
            release.set()
            for _ in range(
                100,
            ):
                if service._pending == 0:
                    break
                await asyncio.sleep(
                    0.001,
                )
            assert (await request()).transcript == "test speech"
        finally:
            release.set()
            await service.close()

    asyncio.run(
        run(),
    )


def test_queue_wait_timeout_releases_only_waiter_and_silence_has_no_transcript(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    entered, release = Event(), Event()

    def recognize(
        audio: bytes,
    ) -> str:
        entered.set()
        release.wait(
            5,
        )
        return " "

    monkeypatch.setattr(
        TOneWorker,
        "transcribe",
        recognize,
    )

    async def run() -> None:
        service = TOneTranscriptionService(
            None,
            TOneConfig(
                max_waiting_requests=1,
                queue_timeout_seconds=0.02,
            ),
        )
        service._executor = ThreadPoolExecutor(
            max_workers=1,
        )

        async def request():
            return await service.transcribe(
                b"\x00\x00",
                language=LanguageCode.RU,
                content_type="application/octet-stream",
            )

        try:
            first = asyncio.create_task(
                request(),
            )
            assert await asyncio.to_thread(
                entered.wait,
                2,
            )
            with pytest.raises(
                SpeechBusyError,
            ):
                await request()
            assert service._pending == 1
            release.set()
            with pytest.raises(
                NoSpeechError,
            ):
                await first
            assert service._pending == 0
        finally:
            release.set()
            await service.close()

    asyncio.run(
        run(),
    )


def test_audio_requires_paid_feature_before_recognition(
    app: FastAPI,
) -> None:
    from app.error.billing_limit_error import BillingLimitError

    subscriptions = AsyncMock(
        spec=SubscriptionService,
    )
    subscriptions.authenticate.return_value = "owner"
    subscriptions.require_feature.side_effect = BillingLimitError()
    app.state.container = replace(
        app.state.container,
        subscription_service=subscriptions,
    )
    app.dependency_overrides[AppCheck.verify] = lambda: None
    del app.dependency_overrides[BillingDependencies.dictation_access]
    speech = AsyncMock(
        spec=TOneTranscriptionService,
    )
    app.dependency_overrides[ServiceDependencies.audio_parsing] = lambda: AudioParsingService(
        app.state.container.configuration,
        speech,
        app.state.container.transcript_parsing_service,
    )

    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(
                app=app,
            ),
            base_url="http://test",
        ) as client:
            response = await client.post(
                _ROUTE,
                content=b"\x00\x00",
                headers={"Authorization": "Bearer test-owner-secret"},
            )
            assert response.status_code == BillingLimitError.status_code
            subscriptions.require_feature.assert_awaited_once_with(
                "owner",
                "formCompletionViaMicrophone",
            )
            speech.transcribe.assert_not_called()

    asyncio.run(
        run(),
    )


@pytest.mark.parametrize(
    "failure",
    ["unknown_model", "silence", "inference"],
)
def test_audio_failure_stops_the_pipeline_without_extra_model_calls(
    app: FastAPI,
    failure: str,
) -> None:
    speech = AsyncMock(
        spec=TOneTranscriptionService,
    )
    speech.transcribe.return_value = SpeechTranscriptResponse(
        transcript="test speech",
    )
    model = AsyncMock(
        spec=NeuralModelService,
    )
    model.call.return_value = "[]"
    if failure == "silence":
        speech.transcribe.side_effect = NoSpeechError()
    if failure == "inference":
        from app.error.inference_timeout_error import InferenceTimeoutError

        model.call.side_effect = InferenceTimeoutError()
    parser = TranscriptParsingService(
        app.state.container.configuration,
        model,
    )
    service = AudioParsingService(
        app.state.container.configuration,
        speech,
        parser,
    )
    app.dependency_overrides[ServiceDependencies.audio_parsing] = lambda: service
    app.dependency_overrides[AppCheck.verify] = lambda: None

    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(
                app=app,
            ),
            base_url="http://test",
        ) as client:
            route = (
                _ROUTE.replace(
                    "google%2Fmedgemma-4b-it",
                    "missing",
                )
                if failure == "unknown_model"
                else _ROUTE
            )
            response = await client.post(
                route,
                content=b"\0\0",
                headers={"Content-Type": "application/octet-stream", "Accept-Language": "ru"},
            )
            assert response.status_code in (400, 422, 504)
            assert "test speech" not in response.text
            assert speech.transcribe.await_count == (0 if failure == "unknown_model" else 1)
            assert model.call.await_count == (1 if failure == "inference" else 0)

    asyncio.run(
        run(),
    )
