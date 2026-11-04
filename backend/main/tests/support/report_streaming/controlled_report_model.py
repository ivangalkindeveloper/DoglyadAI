from __future__ import annotations

import asyncio
from collections.abc import AsyncGenerator

from app.model.neural_model.neural_model_service_request import NeuralModelServiceRequest
from app.service.neural_model.neural_model_service import NeuralModelService


class ControlledReportModel(NeuralModelService):
    def __init__(
        self,
    ) -> None:
        self.first = asyncio.Event()
        self.proceed = asyncio.Event()
        self.calls = 0

    async def call(
        self,
        request: NeuralModelServiceRequest,
    ) -> str:
        return '{"description":"Synthetic description.","conclusion":"Synthetic conclusion."}'

    async def stream(
        self,
        request: NeuralModelServiceRequest,
    ) -> AsyncGenerator[str, None]:
        self.calls += 1
        yield '{"description":"Synthetic '
        self.first.set()
        await self.proceed.wait()
        yield 'description.","conclusion":"Synthetic conclusion."}'
