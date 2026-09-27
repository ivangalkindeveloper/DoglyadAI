from __future__ import annotations

import json
from collections.abc import Iterable
from pathlib import Path

import httpx

from app.core.variables import variables
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)
from app.service.base import ModelService
from app.service.inference import InferenceService

_GENERATION_PATH = "/v1/generation"


def _load_vm_urls(path: Path) -> dict[str, str]:
    if not path.exists():
        raise RuntimeError(f"Model URLs file not found: {path}")
    try:
        with open(path, encoding="utf-8-sig") as file:
            data = json.load(file)
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f"Failed to read model URLs from {path}: {error}") from error
    if not isinstance(data, dict):
        raise RuntimeError(f"Model URLs file {path} must contain a JSON object of modelId -> url")
    vm_urls: dict[str, str] = {}
    for model_id, value in data.items():
        if not isinstance(model_id, str) or not model_id.strip() or not isinstance(value, str) or not value.strip():
            raise RuntimeError(f"Model URLs file {path} contains an invalid model ID or URL")
        vm_urls[model_id] = value.strip()
    return vm_urls


def _generation_endpoint(url: str) -> str:
    # Endpoint maps historically contained the old /v1 route. Treat either a VM
    # base URL or a full legacy endpoint as the same VM address so this contract
    # change does not require an atomic secrets rollout.
    try:
        parsed = httpx.URL(url)
    except httpx.InvalidURL as error:
        raise RuntimeError(f"Invalid GPU VM URL: {url}") from error
    if (
        parsed.scheme not in ("http", "https")
        or not parsed.host
        or parsed.username
        or parsed.password
        or parsed.query
        or parsed.fragment
        or (parsed.path not in ("", "/") and not parsed.path.startswith("/v1/"))
    ):
        raise RuntimeError(f"Invalid GPU VM URL: {url}")
    base_url = str(parsed).split("/v1/", maxsplit=1)[0].rstrip("/")
    return f"{base_url}{_GENERATION_PATH}"


def create_model_service(
    http_client: httpx.AsyncClient,
    configured_models: Iterable[USExaminationNeuralModel],
) -> ModelService:
    """Builds the `ModelService` every request goes through.

    The same composition in every environment — `development` and `production`
    differ only in which config directory they read, never in how a report is
    produced. Testing against a real backend is therefore testing the real path.

    Called eagerly at startup, so a broken configuration aborts the process
    instead of failing the first request. Every configured model is served
    by a dedicated GPU VM selected through the inference endpoint map.
    """
    if not variables.inference_endpoints_path:
        raise RuntimeError("INFERENCE_ENDPOINTS_PATH is not set")

    vm_urls = _load_vm_urls(variables.inference_endpoints_path)
    generation_endpoints = {model_id: _generation_endpoint(url) for model_id, url in vm_urls.items()}
    available_model_ids = {
        model.id
        for model in configured_models
        if model.accessibility is USExaminationNeuralModelAccessibility.AVAILABLE
    }
    missing_model_ids = available_model_ids - generation_endpoints.keys()
    if missing_model_ids:
        raise RuntimeError(f"No GPU VM configured for available models: {', '.join(sorted(missing_model_ids))}")
    return InferenceService(http_client, generation_endpoints)
