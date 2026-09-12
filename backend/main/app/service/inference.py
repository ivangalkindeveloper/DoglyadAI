from __future__ import annotations

import logging

import httpx
from fastapi import HTTPException
from pydantic import ValidationError

from app.core.app_check import APP_CHECK_HEADER
from app.core.variables import variables
from app.model.inference.inference_generation_image import InferenceGenerationImage
from app.model.inference.inference_generation_request import InferenceGenerationRequest
from app.model.inference.inference_response import InferenceGenerationResponse
from app.service.base import InferenceRequest, ModelService

logger = logging.getLogger(__name__)


class InferenceService(ModelService):
    """Inference through dedicated GPU VMs, one per model.

    Each VM runs the `backend/inference` service next to a local vLLM instance
    holding that model. This backend stays on a non-GPU machine and only routes:
    it builds the prompts and picks the VM by model id.
    """

    def __init__(
        self,
        http_client: httpx.AsyncClient,
        generation_endpoints: dict[str, str],
    ) -> None:
        self._http_client = http_client
        self._urls = generation_endpoints
        self._timeout = variables.inference_request_timeout_seconds
        logger.info("Inference service configured for models: %s", ", ".join(sorted(self._urls)) or "none")

    async def call(self, request: InferenceRequest) -> str:
        model_id = request.neural_model.id
        url = self._urls.get(model_id)
        if not url:
            logger.error("No GPU VM is configured for model %s", model_id)
            raise HTTPException(status_code=500, detail="Service is not configured")

        headers = {"Content-Type": "application/json"}
        if request.app_check_token:
            # Already verified at the edge; the GPU VM verifies it again because it
            # is exposed on the network and must not serve anyone who merely knows
            # its address.
            headers[APP_CHECK_HEADER] = request.app_check_token

        payload = InferenceGenerationRequest(
            modelId=model_id,
            systemPrompt=request.system_prompt,
            prompt=request.prompt,
            structuredOutput=request.structured_output,
            images=[InferenceGenerationImage(data=photo.data) for photo in request.photos] or None,
            temperature=request.settings.temperature,
            maxTokens=request.settings.maxTokens,
        )
        # Never log the payload contents: it holds patient data and scan images.
        logger.info(
            "Inference request: model=%s, photos=%d, prompt_chars=%d",
            model_id,
            len(request.photos),
            len(request.prompt),
        )

        try:
            response = await self._http_client.post(
                url,
                headers=headers,
                json=payload.model_dump(exclude_none=True),
                timeout=self._timeout,
            )
        except httpx.HTTPError as error:
            logger.exception("Inference request failed: %s", error)
            raise HTTPException(status_code=502, detail="Inference service is unavailable") from error

        logger.info("Inference response: status=%d", response.status_code)
        if response.status_code >= 400:
            # The response body may echo the request — log the status only.
            logger.error("Inference request returned error status %d", response.status_code)
            # 401/403 mean the App Check token did not pass on the GPU VM. Keep the
            # status so the caller is told to re-authenticate.
            if response.status_code in (401, 403):
                raise HTTPException(status_code=response.status_code, detail="App Check verification failed")
            raise HTTPException(status_code=502, detail="Inference service returned an error")

        try:
            parsed = InferenceGenerationResponse.model_validate(response.json())
            value = parsed.value()
            logger.info("Inference value: model=%s, chars=%d", model_id, len(value))
            return value
        except (ValueError, ValidationError) as error:
            logger.exception("Failed to parse Inference response: %s", error)
            raise HTTPException(status_code=502, detail="Invalid response from inference service") from error
