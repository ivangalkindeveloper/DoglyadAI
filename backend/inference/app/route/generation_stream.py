from __future__ import annotations

import json
from collections.abc import AsyncIterator
from contextlib import aclosing
from typing import Annotated

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse

from app.core.get_vllm_service import get_vllm_service
from app.error.api_error import ApiError
from app.model.generation_request import GenerationRequest
from app.service.vllm_service import VLLMService

router = APIRouter()


@router.post(
    "/generation/stream",
)
async def generation_stream(
    body: GenerationRequest,
    service: Annotated[
        VLLMService,
        Depends(
            get_vllm_service,
        ),
    ],
) -> StreamingResponse:
    async def events() -> AsyncIterator[str]:
        try:
            async with aclosing(
                service.stream(
                    body,
                ),
            ) as source:
                async for text in source:
                    yield (
                        "data: "
                        + json.dumps(
                            {"type": "delta", "modelId": body.modelId, "text": text},
                        )
                        + "\n\n"
                    )
            yield (
                "data: "
                + json.dumps(
                    {"type": "completed", "modelId": body.modelId},
                )
                + "\n\n"
            )
        except ApiError as error:
            yield (
                "data: "
                + json.dumps(
                    {"type": "failed", "modelId": body.modelId, "code": error.code},
                )
                + "\n\n"
            )
        except Exception:
            yield (
                "data: "
                + json.dumps(
                    {"type": "failed", "modelId": body.modelId, "code": "internalServerError"},
                )
                + "\n\n"
            )

    return StreamingResponse(
        events(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-store"},
    )
