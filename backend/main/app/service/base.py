from __future__ import annotations

from abc import ABC, abstractmethod

from app.model.inference.inference_request import InferenceRequest


class ModelService(ABC):
    @abstractmethod
    async def call(self, request: InferenceRequest) -> str:
        """Runs one generation and returns structured content as JSON text."""
        ...
