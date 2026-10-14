from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.model.generation_response import GenerationResponse


@pytest.mark.parametrize("field", ["modelId", "response"])
@pytest.mark.parametrize("blank", ["", " ", "\n\t"])
def test_generation_response_rejects_blank_required_strings(field: str, blank: str) -> None:
    data = {"modelId": "model", "response": '{"value": 1}'}
    data[field] = blank
    with pytest.raises(ValidationError):
        GenerationResponse.model_validate(data)
