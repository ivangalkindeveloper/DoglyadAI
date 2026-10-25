from __future__ import annotations

import logging
from contextlib import AbstractAsyncContextManager
from types import TracebackType

import httpx
from fastapi import FastAPI

from app.core.init_app_check import init_app_check
from app.core.variables import Variables
from app.service.vllm_service import VLLMService

logger = logging.getLogger(__name__)


class InferenceLifespan(AbstractAsyncContextManager[None]):
    def __init__(self, app: FastAPI) -> None:
        self._app = app
        self._http_client = httpx.AsyncClient(timeout=app.state.server_config.vllm.timeout())

    async def __aenter__(self) -> None:
        try:
            variables: Variables = self._app.state.variables
            init_app_check(variables)
            self._app.state.vllm_service = VLLMService(self._http_client, variables, self._app.state.server_config)
            logger.info(
                "Inference service started: model=%s, vllm=%s", variables.served_model_id, variables.vllm_base_url
            )
        except BaseException:
            await self._http_client.aclose()
            raise

    async def __aexit__(
        self, exc_type: type[BaseException] | None, exc_value: BaseException | None, traceback: TracebackType | None
    ) -> None:
        await self._http_client.aclose()
