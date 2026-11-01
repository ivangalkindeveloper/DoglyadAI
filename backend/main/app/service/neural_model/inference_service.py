from __future__ import annotations

import asyncio
import logging

import httpx
from pydantic import ValidationError

from app.core.http.http_header import HttpHeader
from app.error import (
    AppCheckAccessDeniedError,
    InferenceBusyError,
    InferenceResponseError,
    InferenceTimeoutError,
    InferenceUnavailableError,
    InvalidAppCheckTokenError,
    InvalidInferenceResponseError,
    ServiceNotConfiguredError,
)
from app.model.http_client_config import HttpClientConfig
from app.model.inference.inference_generation_image import InferenceGenerationImage
from app.model.inference.inference_generation_request import InferenceGenerationRequest
from app.model.inference.inference_generation_response import InferenceGenerationResponse
from app.model.neural_model.neural_model_service_request import NeuralModelServiceRequest
from app.service.neural_model.neural_model_service import NeuralModelService

logger = logging.getLogger(
    __name__,
)


class InferenceService(NeuralModelService):
    """Inference through GPU hosts with one or more model engines.

    Each host runs `backend/inference` beside its local vLLM engines. Multiple
    model IDs can share its URL. Main stays on a non-GPU machine and sends the
    selected model ID with the prepared prompt.
    """

    def __init__(
        self,
        http_client: httpx.AsyncClient,
        generation_endpoints: dict[str, str],
        http_config: HttpClientConfig,
    ) -> None:
        self._http_client = http_client
        self._urls = generation_endpoints
        self._http_config = http_config
        logger.info(
            "Inference service configured for models: %s",
            ", ".join(
                sorted(
                    self._urls,
                ),
            )
            or "none",
        )

    async def call(
        self,
        request: NeuralModelServiceRequest,
    ) -> str:
        model_id = request.model_id
        url = self._urls.get(
            model_id,
        )
        if not url:
            raise ServiceNotConfiguredError()

        headers = {HttpHeader.CONTENT_TYPE.value: "application/json"}
        if request.app_check_token:
            # Already verified at the edge; the GPU VM verifies it again because it
            # is exposed on the network and must not serve anyone who merely knows
            # its address.
            headers[HttpHeader.FIREBASE_APP_CHECK.value] = request.app_check_token
        if request.request_id:
            headers[HttpHeader.REQUEST_ID.value] = request.request_id

        payload = InferenceGenerationRequest(
            modelId=model_id,
            systemPrompt=request.system_prompt,
            prompt=request.prompt,
            structuredOutput=request.structured_output,
            images=[
                InferenceGenerationImage(
                    data=photo.data,
                )
                for photo in request.photos
            ]
            or None,
            temperature=request.temperature,
            maxTokens=request.max_tokens,
        )
        # Never log the payload contents: it holds patient data and scan images.
        logger.info(
            "Inference request: model=%s, photos=%d, prompt_chars=%d",
            model_id,
            len(
                request.photos,
            ),
            len(
                request.prompt,
            ),
        )

        try:
            async with asyncio.timeout(
                self._http_config.operation_timeout_seconds,
            ):
                response = await self._http_client.post(
                    url,
                    headers=headers,
                    json=payload.model_dump(
                        exclude_none=True,
                    ),
                    timeout=self._http_config.timeout(),
                )
        except (TimeoutError, httpx.TimeoutException) as error:
            raise InferenceTimeoutError() from error
        except httpx.HTTPError as error:
            raise InferenceUnavailableError() from error

        logger.info(
            "Inference response: status=%d",
            response.status_code,
        )
        if response.status_code >= 400:
            # 401/403 mean the App Check token did not pass on the GPU VM. Keep the
            # status so the caller is told to re-authenticate.
            if response.status_code == 503:
                raise InferenceBusyError.from_retry_after(
                    response.headers.get(
                        "Retry-After",
                    ),
                )
            if response.status_code == 504:
                raise InferenceTimeoutError()
            if response.status_code == 401:
                raise InvalidAppCheckTokenError()
            if response.status_code == 403:
                raise AppCheckAccessDeniedError()
            raise InferenceResponseError()

        try:
            parsed = InferenceGenerationResponse.model_validate(
                response.json(),
            )
            if parsed.modelId != model_id:
                raise InvalidInferenceResponseError()
            value = parsed.value()
            logger.info(
                "Inference value: model=%s, chars=%d",
                model_id,
                len(
                    value,
                ),
            )
            return value
        except (ValueError, ValidationError) as error:
            raise InvalidInferenceResponseError() from error
