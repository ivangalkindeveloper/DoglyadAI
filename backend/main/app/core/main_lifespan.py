from __future__ import annotations

import logging
from contextlib import AbstractAsyncContextManager
from types import TracebackType

import httpx
from fastapi import FastAPI

from app.core.app_check import init_app_check
from app.core.config import load_configs
from app.core.variables import variables
from app.service import create_model_service

logger = logging.getLogger(__name__)


class MainLifespan(AbstractAsyncContextManager[None]):
    def __init__(self, app: FastAPI) -> None:
        self._app = app
        self._http_client = httpx.AsyncClient(timeout=variables.inference_request_timeout_seconds)

    async def __aenter__(self) -> None:
        self._app.state.http_client = self._http_client

        try:
            load_configs()
            init_app_check()
            self._app.state.model_service = create_model_service(self._http_client)
        except RuntimeError as error:
            logger.critical("Application startup aborted: %s", error)
            await self._http_client.aclose()
            raise

    async def __aexit__(
        self,
        exc_type: type[BaseException] | None,
        exc_value: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        await self._http_client.aclose()
