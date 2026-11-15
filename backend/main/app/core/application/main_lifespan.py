from __future__ import annotations

from contextlib import AbstractAsyncContextManager
from types import TracebackType

import httpx
from fastapi import FastAPI

from app.core.app_check.app_check import AppCheck
from app.core.application.service_factory import ServiceFactory
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.configuration.variables import Variables
from app.database.application_database import ApplicationDatabase
from app.service.speech.t_one_transcription_service import TOneTranscriptionService


class MainLifespan(AbstractAsyncContextManager[None]):
    def __init__(
        self,
        app: FastAPI,
        *,
        is_speech_enabled: bool,
    ) -> None:
        self._app = app
        self._is_speech_enabled = is_speech_enabled
        self._http_client = httpx.AsyncClient(
            timeout=app.state.server_config.inference.timeout(),
        )
        self._database: ApplicationDatabase | None = None
        self._speech_service: TOneTranscriptionService | None = None

    async def __aenter__(
        self,
    ) -> None:
        try:
            variables: Variables = self._app.state.variables
            configuration = ConfigurationLoader(
                variables.configuration_directory,
            ).load(
                self._app.state.server_config,
            )
            AppCheck.initialize(
                variables,
            )
            factory = ServiceFactory(
                self._http_client,
                configuration,
                variables,
            )
            subscription_service = None
            if variables.database_url:
                self._database = ApplicationDatabase(
                    variables.database_url,
                )
                await self._database.check()
                subscription_service = factory.create_subscriptions(
                    self._database,
                )
            self._app.state.container = factory.create_main_container(
                subscription_service,
                is_speech_enabled=self._is_speech_enabled,
            )
            self._speech_service = self._app.state.container.speech_transcription_service
            if self._speech_service is not None:
                await self._speech_service.start()
        except BaseException:
            try:
                if self._speech_service is not None:
                    await self._speech_service.close()
                if self._database is not None:
                    await self._database.close()
            finally:
                await self._http_client.aclose()
            raise

    async def __aexit__(
        self,
        exc_type: type[BaseException] | None,
        exc_value: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        try:
            if self._speech_service is not None:
                await self._speech_service.close()
            if self._database is not None:
                await self._database.close()
        finally:
            await self._http_client.aclose()
