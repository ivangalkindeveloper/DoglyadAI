from __future__ import annotations

import json
from pathlib import Path

import httpx

from app.core.variables import variables
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
    return {str(key): value.strip() for key, value in data.items() if isinstance(value, str) and value.strip()}


def _generation_endpoint(url: str) -> str:
    # Endpoint maps historically contained the old /v1 route. Treat either a VM
    # base URL or a full legacy endpoint as the same VM address so this contract
    # change does not require an atomic secrets rollout.
    base_url = url.split("/v1/", maxsplit=1)[0].rstrip("/")
    if not base_url:
        raise RuntimeError(f"Invalid GPU VM URL: {url}")
    return f"{base_url}{_GENERATION_PATH}"


def create_model_service(http_client: httpx.AsyncClient) -> ModelService:
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
    return InferenceService(http_client, generation_endpoints)
