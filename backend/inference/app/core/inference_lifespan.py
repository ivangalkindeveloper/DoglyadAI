from __future__ import annotations

import logging
from contextlib import AbstractAsyncContextManager
from types import TracebackType

import httpx
from fastapi import FastAPI

from app.core.app_check import init_app_check
from app.core.variables import variables
from app.service import init_services

logger = logging.getLogger(__name__)


class InferenceLifespan(AbstractAsyncContextManager[None]):
    def __init__(self, app: FastAPI) -> None:
        self._app = app
        self._http_client = httpx.AsyncClient(timeout=variables.vllm_request_timeout_seconds)

    async def __aenter__(self) -> None:
        self._app.state.http_client = self._http_client

        try:
            init_app_check()
            init_services(self._http_client)
        except RuntimeError as error:
            logger.critical("Application startup aborted: %s", error)
            await self._http_client.aclose()
            raise

        logger.info(
            "Inference service started: model=%s, vllm=%s",
            variables.served_model_id,
            variables.vllm_base_url,
        )

    async def __aexit__(
        self,
        exc_type: type[BaseException] | None,
        exc_value: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        await self._http_client.aclose()
