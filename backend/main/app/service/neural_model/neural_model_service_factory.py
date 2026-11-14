from __future__ import annotations

import json
import logging
from collections.abc import Iterable
from pathlib import Path
from typing import assert_never

import httpx

from app.core.configuration.neural_model_service_type import NeuralModelServiceType
from app.core.configuration.variables import Variables
from app.model.http_client_config import HttpClientConfig
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)
from app.service.neural_model.inference_service import InferenceService
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService
from app.service.neural_model.neural_model_service import NeuralModelService

logger = logging.getLogger(
    __name__,
)


class NeuralModelServiceFactory:
    GENERATION_PATH = "/v1/generation"

    def __init__(
        self,
    ) -> None:
        pass

    @classmethod
    def _load_vm_urls(
        cls,
        path: Path,
    ) -> dict[str, str]:
        if not path.exists():
            raise RuntimeError(
                f"Model URLs file not found: {path}",
            )
        try:
            with open(
                path,
                encoding="utf-8-sig",
            ) as file:
                data = json.load(
                    file,
                )
        except (OSError, json.JSONDecodeError) as error:
            raise RuntimeError(
                f"Failed to read model URLs from {path}: {error}",
            ) from error
        if not isinstance(
            data,
            dict,
        ):
            raise RuntimeError(
                f"Model URLs file {path} must contain a JSON object of modelId -> url",
            )
        vm_urls: dict[str, str] = {}
        for model_id, value in data.items():
            if (
                not isinstance(
                    model_id,
                    str,
                )
                or not model_id.strip()
                or not isinstance(
                    value,
                    str,
                )
                or not value.strip()
            ):
                raise RuntimeError(
                    f"Model URLs file {path} contains an invalid model ID or URL",
                )
            vm_urls[model_id] = value.strip()
        return vm_urls

    @classmethod
    def _generation_endpoint(
        cls,
        url: str,
        *,
        is_stream: bool = False,
    ) -> str:
        # Endpoint maps historically contained the old /v1 route. Treat either a VM
        # base URL or a full legacy endpoint as the same VM address so this contract
        # change does not require an atomic secrets rollout.
        try:
            parsed = httpx.URL(
                url,
            )
        except httpx.InvalidURL as error:
            raise RuntimeError(
                f"Invalid GPU VM URL: {url}",
            ) from error
        if (
            parsed.scheme not in ("http", "https")
            or not parsed.host
            or parsed.username
            or parsed.password
            or parsed.query
            or parsed.fragment
            or (
                parsed.path not in ("", "/")
                and not parsed.path.startswith(
                    "/v1/",
                )
            )
        ):
            raise RuntimeError(
                f"Invalid GPU VM URL: {url}",
            )
        base_url = (
            str(
                parsed,
            )
            .split(
                "/v1/",
                maxsplit=1,
            )[0]
            .rstrip(
                "/",
            )
        )
        return f"{base_url}{cls.GENERATION_PATH}" + ("/stream" if is_stream else "")

    @classmethod
    def create(
        cls,
        http_client: httpx.AsyncClient,
        configured_models: Iterable[USExaminationNeuralModel],
        variables: Variables,
        http_config: HttpClientConfig,
    ) -> NeuralModelService:
        """Selects generation once at startup, independently of the config environment."""
        logger.info(
            "Model service type: %s",
            variables.model_service_type.value,
        )
        match variables.model_service_type:
            case NeuralModelServiceType.INFERENCE:
                return cls._create_inference_service(
                    http_client,
                    configured_models,
                    variables,
                    http_config,
                )
            case NeuralModelServiceType.MOCK:
                return MockNeuralModelService()
        assert_never(
            variables.model_service_type,
        )

    @classmethod
    def _create_inference_service(
        cls,
        http_client: httpx.AsyncClient,
        configured_models: Iterable[USExaminationNeuralModel],
        variables: Variables,
        http_config: HttpClientConfig,
    ) -> InferenceService:
        """Validates the GPU endpoint map before serving the first real request."""
        if not variables.inference_endpoints_path:
            raise RuntimeError(
                "INFERENCE_ENDPOINTS_PATH is not set",
            )

        vm_urls = cls._load_vm_urls(
            variables.inference_endpoints_path,
        )
        generation_endpoints = {
            model_id: cls._generation_endpoint(
                url,
            )
            for model_id, url in vm_urls.items()
        }
        available_model_ids = {
            model.id
            for model in configured_models
            if model.accessibility is USExaminationNeuralModelAccessibility.AVAILABLE
        }
        missing_model_ids = available_model_ids - generation_endpoints.keys()
        if missing_model_ids:
            raise RuntimeError(
                f"No GPU VM configured for available models: {', '.join(sorted(missing_model_ids))}",
            )
        return InferenceService(
            http_client,
            generation_endpoints,
            http_config,
            {
                model_id: cls._generation_endpoint(
                    url,
                    is_stream=True,
                )
                for model_id, url in vm_urls.items()
            },
        )
