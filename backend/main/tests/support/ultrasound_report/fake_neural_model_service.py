from __future__ import annotations

import json

from app.model.neural_model.neural_model_service_request import NeuralModelServiceRequest


class FakeNeuralModelService:
    def __init__(self, invalid_report: bool = False) -> None:
        self._invalid_report = invalid_report

    async def call(self, request: NeuralModelServiceRequest) -> str:
        assert request.system_prompt == "system prompt"
        assert request.prompt == "user prompt"
        assert request.app_check_token == "app-check-token"
        assert request.request_id == "a" * 32
        schema = json.loads(request.structured_output)
        assert set(schema["properties"]) == {"description", "conclusion", "recommendations", "descriptionRemarks"}
        assert schema["additionalProperties"] is False
        return json.dumps(
            {
                "description": "Generated description",
                "conclusion": ["Sensitive generated patient text"] if self._invalid_report else "Generated conclusion",
                "recommendations": "Generated recommendations",
            }
        )
