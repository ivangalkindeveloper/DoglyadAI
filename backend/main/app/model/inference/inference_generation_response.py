from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.non_blank_string import NonBlankString


class InferenceGenerationResponse(BaseModel):
    """The response of `POST /v1/generation` on a GPU VM.

    Mirrors `GenerationResponse` in backend/inference.
    """

    model_config = ConfigDict(extra="ignore")

    modelId: NonBlankString
    response: NonBlankString

    def value(self) -> str:
        text = self.response.strip()
        if not text:
            raise ValueError("Inference service response contains no content")
        return text
