from __future__ import annotations

from abc import ABC, abstractmethod
from collections.abc import AsyncGenerator

from app.model.neural_model.neural_model_service_request import NeuralModelServiceRequest


class NeuralModelService(ABC):
    def __init__(
        self,
    ) -> None:
        super().__init__()

    @abstractmethod
    async def call(
        self,
        request: NeuralModelServiceRequest,
    ) -> str:
        """Runs one generation and returns structured content as JSON text."""
        ...

    async def stream(
        self,
        request: NeuralModelServiceRequest,
    ) -> AsyncGenerator[str, None]:
        """Mocks can deliver one complete chunk; remote inference overrides this method."""
        yield await self.call(
            request,
        )
