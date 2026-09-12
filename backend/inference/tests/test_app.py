from __future__ import annotations

import asyncio
import json

import httpx
import pytest
from fastapi import HTTPException


def test_app_exposes_routes() -> None:
    from app.main import app

    paths = {getattr(route, "path", None) for route in app.routes}
    assert "/v1/generation" in paths


def test_no_route_is_reachable_without_app_check() -> None:
    # This service has no unauthenticated surface at all: every route it serves
    # sits under /v1, and /v1 is closed. Anything added outside it would be
    # reachable by whoever can reach the port, which is the thing App Check exists
    # to prevent here.
    from app.core.app_check import verify_app_check
    from app.main import app

    for route in app.routes:
        path = str(getattr(route, "path", ""))
        if not path.startswith("/v1/"):
            continue
        dependencies = [call.call for call in route.dependant.dependencies]  # type: ignore[attr-defined]
        assert verify_app_check in dependencies, f"{path} is not behind App Check"


def test_generation_is_behind_app_check() -> None:
    # The one control this service has: it holds the model and is reachable over
    # the network, so an unverified caller must never get past the router. There is
    # no flag to switch this off — dropping the dependency is the only way to lose
    # it, which is what this test guards.
    from app.core.app_check import verify_app_check
    from app.main import app

    route = next(route for route in app.routes if getattr(route, "path", None) == "/v1/generation")
    dependencies = [call.call for call in route.dependant.dependencies]  # type: ignore[attr-defined]
    assert verify_app_check in dependencies


def test_missing_token_is_rejected() -> None:
    # Rejected before Firebase is consulted, so this holds even on a service that
    # never finished initializing the SDK.
    from app.core.app_check import verify_app_check

    with pytest.raises(HTTPException) as error:
        asyncio.run(verify_app_check(None))

    assert error.value.status_code == 401


def test_generate_rejects_another_model() -> None:
    # One VM per model: accepting a different id would use the wrong model.
    from app.model.generation_request import GenerationRequest
    from app.service.vllm import VLLMService

    async def run() -> None:
        async with httpx.AsyncClient() as client:
            service = VLLMService(client)
            request = GenerationRequest(
                modelId="example/other-model",
                systemPrompt="system",
                prompt="prompt",
                structuredOutput='{"type":"object"}',
            )
            with pytest.raises(HTTPException) as error:
                await service.generate(request)
            assert error.value.status_code == 400

    asyncio.run(run())


def test_generate_forwards_images_and_json_schema() -> None:
    from app.model.generation_image import GenerationImage
    from app.model.generation_request import GenerationRequest
    from app.service.vllm import VLLMService

    seen: dict[str, object] = {}
    schema = {
        "type": "object",
        "properties": {"value": {"type": "string"}},
        "required": ["value"],
        "additionalProperties": False,
    }

    def handler(request: httpx.Request) -> httpx.Response:
        seen.update(json.loads(request.content))
        return httpx.Response(
            200,
            json={
                "choices": [{"message": {"content": '{"value":"generated"}'}, "finish_reason": "stop"}],
                "usage": {"prompt_tokens": 10, "completion_tokens": 5},
            },
        )

    async def run() -> str:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            service = VLLMService(client)
            return await service.generate(
                GenerationRequest(
                    modelId="example/served-model",
                    systemPrompt="system",
                    prompt="prompt",
                    structuredOutput=json.dumps(schema),
                    images=[GenerationImage(data="QUJD")],
                )
            )

    assert asyncio.run(run()) == '{"value":"generated"}'
    assert seen["response_format"] == {
        "type": "json_schema",
        "json_schema": {"name": "structured_response", "schema": schema},
    }
    messages = seen["messages"]
    assert isinstance(messages, list)
    assert messages[1]["content"][1] == {
        "type": "image_url",
        "image_url": {"url": "data:image/jpeg;base64,QUJD"},
    }


def test_generate_omits_optional_fields_and_accepts_plain_text() -> None:
    from app.model.generation_request import GenerationRequest
    from app.service.vllm import VLLMService

    seen: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen.update(json.loads(request.content))
        return httpx.Response(
            200,
            json={"choices": [{"message": {"content": "Generated text."}}]},
        )

    async def run() -> str:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            service = VLLMService(client)
            return await service.generate(
                GenerationRequest(
                    modelId="example/served-model",
                    prompt="prompt",
                )
            )

    assert asyncio.run(run()) == "Generated text."
    assert seen == {
        "model": "example/served-model",
        "messages": [
            {
                "role": "user",
                "content": [{"type": "text", "text": "prompt"}],
            }
        ],
    }


def test_vllm_response_value() -> None:
    from app.model.vllm_chat_completion import VLLMChatCompletion

    parsed = VLLMChatCompletion.model_validate(
        {
            "choices": [{"message": {"role": "assistant", "content": "  Generated text.  "}}],
            "usage": {"prompt_tokens": 10, "completion_tokens": 20},
        }
    )
    assert parsed.value() == "Generated text."


def test_vllm_response_rejects_empty_content() -> None:
    from app.model.vllm_chat_completion import VLLMChatCompletion

    parsed = VLLMChatCompletion.model_validate({"choices": [{"message": {"content": ""}}]})
    with pytest.raises(ValueError):
        parsed.value()
