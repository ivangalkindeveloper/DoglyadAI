from __future__ import annotations

from app.model.inference.inference_request import InferenceRequest
from app.service.base import ModelService
from app.service.factory import create_model_service

__all__ = ["InferenceRequest", "ModelService", "create_model_service"]
