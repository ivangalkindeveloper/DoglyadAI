from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

from app.model.inference.inference_generation_image import InferenceGenerationImage
from app.model.inference.inference_generation_request import InferenceGenerationRequest
from app.model.inference.inference_response import InferenceGenerationResponse

_INFERENCE_DIRECTORY = Path(__file__).resolve().parents[2] / "inference"
_INFERENCE_CONTRACT_CHECK = """
import json
import sys

from app.model.generation_request import GenerationRequest
from app.model.generation_response import GenerationResponse

payload = json.load(sys.stdin)
request = GenerationRequest.model_validate(payload)
assert request.model_dump(exclude_none=True) == payload
response = GenerationResponse(modelId=request.modelId, response='{"description":"ok"}')
print(response.model_dump_json())
"""


@pytest.mark.parametrize("include_optional_fields", [False, True])
def test_main_and_inference_generation_contract(include_optional_fields: bool) -> None:
    kwargs: dict[str, object] = {"modelId": "example/model", "prompt": "Describe the scan"}
    if include_optional_fields:
        kwargs.update(
            systemPrompt="Follow the schema",
            structuredOutput='{"type":"object"}',
            images=[InferenceGenerationImage(data="QUJD")],
            temperature=0.3,
            maxTokens=512,
        )
    request = InferenceGenerationRequest.model_validate(kwargs)

    result = subprocess.run(
        [sys.executable, "-c", _INFERENCE_CONTRACT_CHECK],
        input=request.model_dump_json(exclude_none=True),
        text=True,
        capture_output=True,
        check=True,
        cwd=_INFERENCE_DIRECTORY,
        timeout=10,
    )

    response = InferenceGenerationResponse.model_validate_json(result.stdout)
    assert response.modelId == request.modelId
    assert json.loads(response.value()) == {"description": "ok"}
