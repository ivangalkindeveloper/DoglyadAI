from __future__ import annotations

import asyncio
import json
import logging
from typing import Any

import httpx
from pydantic import ValidationError

from app.core.variables import Variables
from app.error import (
    InferenceResponseError,
    InferenceTimeoutError,
    InferenceUnavailableError,
    InvalidInferenceResponseError,
    ModelMismatchError,
)
from app.model.generation_request import GenerationRequest
from app.model.inference_server_config import InferenceServerConfig
from app.model.vllm_chat_completion import VLLMChatCompletion
from app.service.generation_capacity import GenerationCapacity
from app.service.image_request_validator import ImageRequestValidator

logger = logging.getLogger(
    __name__,
)


class VLLMService:
    """Routes known model IDs to private vLLM engines with independent queues."""

    def __init__(
        self,
        http_client: httpx.AsyncClient,
        variables: Variables,
        config: InferenceServerConfig,
    ) -> None:
        self._http_client = http_client
        self._endpoints = variables.model_endpoints
        self._http_config = config.vllm
        self._capacities = {
            model_id: GenerationCapacity(
                config.generation,
            )
            for model_id in self._endpoints
        }
        self._images = ImageRequestValidator(
            config.generation.max_image_bytes,
            config.generation.max_images,
        )

    @property
    def model_ids(
        self,
    ) -> tuple[str, ...]:
        return tuple(
            self._endpoints,
        )

    async def generate(
        self,
        request: GenerationRequest,
    ) -> str:
        # Endpoints come only from trusted host configuration, never from callers.
        base_url = self._endpoints.get(
            request.modelId,
        )
        if base_url is None:
            raise ModelMismatchError()

        self._images.validate(
            [image.data for image in request.images or []],
        )

        messages: list[dict[str, Any]] = []
        if request.systemPrompt is not None:
            messages.append(
                {
                    "role": "system",
                    "content": [{"type": "text", "text": request.systemPrompt}],
                },
            )
        user_content: list[dict[str, Any]] = [{"type": "text", "text": request.prompt}]
        for generation_image in request.images or []:
            user_content.append(
                {
                    "type": "image_url",
                    "image_url": {"url": f"data:image/jpeg;base64,{generation_image.data}"},
                },
            )
        messages.append(
            {"role": "user", "content": user_content},
        )
        payload: dict[str, Any] = {
            "model": request.modelId,
            "messages": messages,
        }
        structured_output_schema = request.structured_output_schema()
        if structured_output_schema is not None:
            payload["response_format"] = {
                "type": "json_schema",
                "json_schema": {
                    "name": "structured_response",
                    "schema": structured_output_schema,
                },
            }
        # Omit rather than send nulls: unset means "use the engine default".
        if request.temperature is not None:
            payload["temperature"] = request.temperature
        if request.maxTokens is not None:
            payload["max_tokens"] = request.maxTokens

        # Never log payload contents because prompts and images may be sensitive.
        logger.info(
            "vLLM request: model=%s, images=%d, prompt_chars=%d, schema_chars=%d",
            request.modelId,
            len(
                request.images or [],
            ),
            len(
                request.prompt,
            ),
            len(
                request.structuredOutput or "",
            ),
        )

        try:
            async with asyncio.timeout(
                self._http_config.operation_timeout_seconds,
            ):
                async with self._capacities[request.modelId].slot():
                    response = await self._http_client.post(
                        f"{base_url}/v1/chat/completions",
                        json=payload,
                        timeout=self._http_config.timeout(),
                    )
        except (TimeoutError, httpx.TimeoutException) as error:
            raise InferenceTimeoutError() from error
        except httpx.HTTPError as error:
            raise InferenceUnavailableError() from error

        logger.info(
            "vLLM response: status=%d",
            response.status_code,
        )
        if response.status_code >= 400:
            raise InferenceResponseError()

        try:
            parsed = VLLMChatCompletion.model_validate(
                response.json(),
            )
            value = parsed.value()
            usage = parsed.usage
            finish_reason = parsed.choices[0].finish_reason
            logger.info(
                "vLLM value: model=%s, chars=%d, finish_reason=%s, prompt_tokens=%d, completion_tokens=%d",
                request.modelId,
                len(
                    value,
                ),
                finish_reason,
                usage.prompt_tokens if usage else 0,
                usage.completion_tokens if usage else 0,
            )
            if request.structuredOutput is not None:
                json.loads(
                    value,
                )
        except (ValueError, ValidationError) as error:
            raise InvalidInferenceResponseError() from error
        return value
