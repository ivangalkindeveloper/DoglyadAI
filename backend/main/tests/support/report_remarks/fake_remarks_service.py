from __future__ import annotations

import json
from typing import Any

from app.model.neural_model.neural_model_service_request import NeuralModelServiceRequest


class FakeRemarksService:
    def __init__(self, value: dict[str, Any]) -> None:
        self.value = value
        self.request: NeuralModelServiceRequest | None = None

    async def call(self, request: NeuralModelServiceRequest) -> str:
        self.request = request
        return json.dumps(self.value)
