from __future__ import annotations

import asyncio
from unittest.mock import patch

import httpx
import pytest
from fastapi.testclient import TestClient

from app.core.application.application_factory import ApplicationFactory
from app.core.application.main_lifespan import MainLifespan
from app.core.configuration.neural_model_service_type import NeuralModelServiceType
from app.core.configuration.variables import Variables


def test_lifespans_build_separate_containers_and_services() -> None:
    settings = Variables(
        environment="development",
        model_service_type=NeuralModelServiceType.MOCK,
    )
    first = ApplicationFactory.create_main(
        settings,
    )
    second = ApplicationFactory.create_main(
        settings.model_copy(),
    )
    with (
        patch(
            "app.core.application.main_lifespan.AppCheck.initialize",
        ),
        TestClient(
            first,
        ),
        TestClient(
            second,
        ),
    ):
        assert first.state.container is not second.state.container
        assert first.state.container.configuration is not second.state.container.configuration
        assert first.state.container.model_service is not second.state.container.model_service


def test_only_main_api_starts_and_closes_speech_service() -> None:
    settings = Variables(
        environment="development",
        model_service_type=NeuralModelServiceType.MOCK,
    )
    main_app = ApplicationFactory.create_main(
        settings,
    )
    payment_app = ApplicationFactory.create_payment(
        settings,
    )
    with (
        patch(
            "app.core.application.main_lifespan.AppCheck.initialize",
        ),
        patch(
            "app.core.application.main_lifespan.TOneTranscriptionService.start",
        ) as start_speech,
        patch(
            "app.core.application.main_lifespan.TOneTranscriptionService.close",
        ) as close_speech,
    ):
        with TestClient(
            payment_app,
        ):
            assert payment_app.state.container.speech_transcription_service is None
            assert payment_app.state.container.audio_parsing_service is None
            start_speech.assert_not_awaited()
        close_speech.assert_not_awaited()
        with TestClient(
            main_app,
        ):
            assert main_app.state.container.speech_transcription_service is not None
            assert main_app.state.container.audio_parsing_service is not None
            start_speech.assert_awaited_once()
            close_speech.assert_not_awaited()
        close_speech.assert_awaited_once()


def test_failed_startup_closes_http_client_even_for_non_runtime_errors() -> None:
    async def run() -> None:
        app = ApplicationFactory.create_main(
            Variables(
                environment="development",
                model_service_type=NeuralModelServiceType.MOCK,
            ),
        )
        client = httpx.AsyncClient()
        with patch(
            "app.core.application.main_lifespan.httpx.AsyncClient",
            return_value=client,
        ):
            lifespan = MainLifespan(
                app,
                is_speech_enabled=True,
            )
        with (
            patch(
                "app.core.application.main_lifespan.AppCheck.initialize",
                side_effect=ValueError(
                    "Synthetic credential error",
                ),
            ),
            pytest.raises(
                ValueError,
                match="Synthetic credential error",
            ),
        ):
            await lifespan.__aenter__()
        assert client.is_closed

    asyncio.run(
        run(),
    )
