from __future__ import annotations

from abc import ABC, abstractmethod

from app.model.neural_model.neural_model_service_request import NeuralModelServiceRequest


class NeuralModelService(ABC):
    @abstractmethod
    async def call(self, request: NeuralModelServiceRequest) -> str:
        """Runs one generation and returns structured content as JSON text."""
        ...
