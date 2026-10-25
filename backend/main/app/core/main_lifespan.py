from __future__ import annotations

import logging
from contextlib import AbstractAsyncContextManager
from types import TracebackType

import httpx
from fastapi import FastAPI

from app.core.configuration_loader import ConfigurationLoader
from app.core.init_app_check import init_app_check
from app.core.main_container import MainContainer
from app.core.variables import Variables
from app.service.configuration_response_service import ConfigurationResponseService
from app.service.create_model_service import create_model_service
from app.service.dictation_parsing_service import DictationParsingService
from app.service.report_email_service import ReportEmailService
from app.service.report_generation_service import ReportGenerationService

logger = logging.getLogger(__name__)


class MainLifespan(AbstractAsyncContextManager[None]):
    def __init__(self, app: FastAPI) -> None:
        self._app = app
        self._http_client = httpx.AsyncClient(timeout=app.state.server_config.inference.timeout())

    async def __aenter__(self) -> None:
        try:
            variables: Variables = self._app.state.variables
            configuration = ConfigurationLoader(variables.configuration_directory).load(self._app.state.server_config)
            init_app_check(variables)
            model_service = create_model_service(
                self._http_client, configuration.neural_models.values(), variables, configuration.server.inference
            )
            self._app.state.container = MainContainer(
                configuration=configuration,
                configuration_responses=ConfigurationResponseService(configuration),
                model_service=model_service,
                report_generation=ReportGenerationService(configuration, model_service),
                dictation_parsing=DictationParsingService(configuration, model_service),
                report_email=ReportEmailService(variables, configuration.server.email),
            )
        except BaseException:
            await self._http_client.aclose()
            raise

    async def __aexit__(
        self, exc_type: type[BaseException] | None, exc_value: BaseException | None, traceback: TracebackType | None
    ) -> None:
        await self._http_client.aclose()
