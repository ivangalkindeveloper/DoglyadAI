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
    entitlement="base",
    accessibility=USExaminationNeuralModelAccessibility.AVAILABLE,
    contextLength=128000,
    descriptionLocaleKey="googleMedGemma4BDescription",
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
    assert isinstance(create_model_service(http_client, [_MODEL]), InferenceService)


def test_model_service_replaces_a_legacy_route_with_generation(
    http_client: httpx.AsyncClient,
    inference_endpoints: Path,
) -> None:
    inference_endpoints.write_text(
        json.dumps({_MODEL.id: "http://10.0.0.11:8100/v1/conclusion_generation"}),
        encoding="utf-8",
    )

    service = create_model_service(http_client, [_MODEL])

    assert isinstance(service, InferenceService)
    assert service._urls[_MODEL.id] == "http://10.0.0.11:8100/v1/generation"


def test_startup_fails_without_an_inference_map(
    http_client: httpx.AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Every request uses a dedicated GPU VM, so a missing map aborts startup.
    monkeypatch.setattr(variables, "inference_endpoints_path", None)

    with pytest.raises(RuntimeError):
        create_model_service(http_client, [_MODEL])


def test_startup_fails_when_available_model_has_no_vm(
    http_client: httpx.AsyncClient,
    inference_endpoints: Path,
) -> None:
    inference_endpoints.write_text("{}", encoding="utf-8")

    with pytest.raises(RuntimeError, match="No GPU VM configured for available models"):
        create_model_service(http_client, [_MODEL])


def test_coming_soon_model_does_not_need_a_vm(
    http_client: httpx.AsyncClient,
    inference_endpoints: Path,
) -> None:
    coming_soon = _MODEL.model_copy(
        update={
            "id": "google/coming-soon",
            "accessibility": USExaminationNeuralModelAccessibility.COMING_SOON,
        }
    )

    assert isinstance(create_model_service(http_client, [_MODEL, coming_soon]), InferenceService)


def test_startup_fails_for_an_invalid_vm_url(
    http_client: httpx.AsyncClient,
    inference_endpoints: Path,
) -> None:
    inference_endpoints.write_text(json.dumps({_MODEL.id: "not-a-url"}), encoding="utf-8")

    with pytest.raises(RuntimeError, match="Invalid GPU VM URL"):
        create_model_service(http_client, [_MODEL])


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
        built.append(type(create_model_service(http_client, [_MODEL])))

    assert built[0] is built[1]
