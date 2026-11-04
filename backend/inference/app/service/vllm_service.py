from __future__ import annotations

import asyncio
import json
import logging
from collections.abc import AsyncGenerator
from contextlib import aclosing
from typing import Any

import httpx

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
from app.service.generation_capacity import GenerationCapacity
from app.service.image_request_validator import ImageRequestValidator
from app.service.sse_decoder import SSEDecoder
from app.service.structured_output_reader import StructuredOutputReader

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
        self._max_response_bytes = config.generation.max_response_bytes
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
        async with aclosing(
            self.stream(
                request,
            ),
        ) as source:
            return "".join(
                [part async for part in source],
            ).strip()

    async def stream(
        self,
        request: GenerationRequest,
    ) -> AsyncGenerator[str, None]:
        """Close upstream as soon as a complete structured value passes its schema."""
        base_url, payload = self._prepare(
            request,
        )
        payload["stream"] = True
        pieces: list[str] = []
        size = 0
        finish: str | None = None
        is_done = False
        completed_content: str | None = None
        try:
            schema = request.structured_output_schema()
            reader = (
                StructuredOutputReader(
                    schema,
                )
                if schema is not None
                else None
            )
            async with asyncio.timeout(
                self._http_config.operation_timeout_seconds,
            ):
                async with self._capacities[request.modelId].slot():
                    async with self._http_client.stream(
                        "POST",
                        f"{base_url}/v1/chat/completions",
                        json=payload,
                        timeout=self._http_config.timeout(),
                    ) as response:
                        if response.status_code >= 400:
                            raise InferenceResponseError()
                        async for data in SSEDecoder(
                            self._max_response_bytes,
                        ).messages(
                            response,
                        ):
                            if data == "[DONE]":
                                is_done = True
                                break
                            event = json.loads(
                                data,
                            )
                            if not isinstance(
                                event,
                                dict,
                            ) or event.get(
                                "error",
                            ):
                                raise InvalidInferenceResponseError()
                            choices = event.get(
                                "choices",
                                [],
                            )
                            if (
                                not isinstance(
                                    choices,
                                    list,
                                )
                                or len(
                                    choices,
                                )
                                > 1
                            ):
                                raise InvalidInferenceResponseError()
                            for choice in choices:
                                if (
                                    not isinstance(
                                        choice,
                                        dict,
                                    )
                                    or choice.get(
                                        "index",
                                        0,
                                    )
                                    != 0
                                ):
                                    raise InvalidInferenceResponseError()
                                delta = choice.get(
                                    "delta",
                                    {},
                                )
                                if not isinstance(
                                    delta,
                                    dict,
                                ):
                                    raise InvalidInferenceResponseError()
                                content = delta.get(
                                    "content",
                                )
                                if content is not None and not isinstance(
                                    content,
                                    str,
                                ):
                                    raise InvalidInferenceResponseError()
                                finish = (
                                    choice.get(
                                        "finish_reason",
                                    )
                                    or finish
                                )
                                if content:
                                    size += len(
                                        content.encode(
                                            "utf-8",
                                        ),
                                    )
                                    if size > self._max_response_bytes:
                                        raise InvalidInferenceResponseError()
                                    if reader is not None:
                                        content = reader.append(
                                            content,
                                        )
                                    pieces.append(
                                        content,
                                    )
                                    if reader is not None and reader.is_complete:
                                        completed_content = content
                                        break
                                    yield content
                            if completed_content is not None:
                                break
                        if completed_content is None:
                            if (
                                not is_done
                                or finish != "stop"
                                or not "".join(
                                    pieces,
                                ).strip()
                            ):
                                raise InvalidInferenceResponseError()
                            if reader is not None:
                                reader.finish()
            logger.info(
                "vLLM stream completed: model=%s, chars=%d, reason=%s",
                request.modelId,
                sum(
                    (
                        len(
                            part,
                        )
                        for part in pieces
                    ),
                ),
                "json_complete" if completed_content is not None else finish,
            )
        except (TimeoutError, httpx.TimeoutException) as error:
            raise InferenceTimeoutError() from error
        except httpx.HTTPError as error:
            raise InferenceUnavailableError() from error
        except (ValueError, TypeError, KeyError, RecursionError) as error:
            raise InvalidInferenceResponseError() from error
        # The final delta is published only after closing HTTP and releasing capacity.
        if completed_content is not None:
            yield completed_content

    def _prepare(
        self,
        request: GenerationRequest,
    ) -> tuple[str, dict[str, Any]]:
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
        if request.repetitionPenalty is not None:
            payload["repetition_penalty"] = request.repetitionPenalty

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

        return base_url, payload
