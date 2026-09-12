from __future__ import annotations

import json
from pathlib import Path

import httpx
import pytest

from app.core.variables import variables
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)
from app.service import create_model_service
from app.service.base import ModelService
from app.service.inference import InferenceService

_MODEL = USExaminationNeuralModel(
    id="google/medgemma-4b-it",
    title="MedGemma 4B",
    accessibility=USExaminationNeuralModelAccessibility.AVAILABLE,
    description={"en": ""},
)


@pytest.fixture
def http_client() -> httpx.AsyncClient:
    return httpx.AsyncClient()


@pytest.fixture
def inference_endpoints(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    path = tmp_path / "inference_endpoints.json"
    path.write_text(json.dumps({_MODEL.id: "http://10.0.0.11:8100"}), encoding="utf-8")
    monkeypatch.setattr(variables, "inference_endpoints_path", path)
    return path


def test_model_service_uses_dedicated_gpu_vms(
    http_client: httpx.AsyncClient,
    inference_endpoints: Path,
) -> None:
    assert isinstance(create_model_service(http_client), InferenceService)


def test_model_service_replaces_a_legacy_route_with_generation(
    http_client: httpx.AsyncClient,
    inference_endpoints: Path,
) -> None:
    inference_endpoints.write_text(
        json.dumps({_MODEL.id: "http://10.0.0.11:8100/v1/conclusion_generation"}),
        encoding="utf-8",
    )

    service = create_model_service(http_client)

    assert isinstance(service, InferenceService)
    assert service._urls[_MODEL.id] == "http://10.0.0.11:8100/v1/generation"


def test_startup_fails_without_an_inference_map(
    http_client: httpx.AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Every request uses a dedicated GPU VM, so a missing map aborts startup.
    monkeypatch.setattr(variables, "inference_endpoints_path", None)

    with pytest.raises(RuntimeError):
        create_model_service(http_client)


def test_the_same_composition_in_every_environment(
    http_client: httpx.AsyncClient,
    inference_endpoints: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # ENVIRONMENT picks a config directory and nothing else: a report is
    # produced by the same services in development as in production. That is what
    # makes testing against a development backend meaningful.
    built: list[type[ModelService]] = []
    for environment in ("development", "production"):
        monkeypatch.setattr(variables, "environment", environment)
        built.append(type(create_model_service(http_client)))

    assert built[0] is built[1]
