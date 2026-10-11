from __future__ import annotations

import json
from typing import Any

from app.model.neural_model.neural_model_service_request import NeuralModelServiceRequest


class FakeNeuralModelService:
    def __init__(self, response: Any) -> None:
        self.response = response
        self.request: NeuralModelServiceRequest | None = None

    async def call(self, request: NeuralModelServiceRequest) -> str:
        self.request = request
        return json.dumps(self.response, ensure_ascii=False)
