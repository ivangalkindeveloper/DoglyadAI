from __future__ import annotations

import json
from pathlib import Path

import httpx
import pytest

from app.core.configuration.configuration import Configuration
from app.core.configuration.neural_model_service_type import NeuralModelServiceType
from app.core.configuration.variables import Variables
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)
from app.service.neural_model.inference_service import InferenceService
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService
from app.service.neural_model.neural_model_service import NeuralModelService
from app.service.neural_model.neural_model_service_factory import NeuralModelServiceFactory

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
def inference_endpoints(
    variables: Variables,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> Path:
    path = tmp_path / "inference_endpoints.json"
    path.write_text(
        json.dumps(
            {_MODEL.id: "http://10.0.0.11:8100"},
        ),
        encoding="utf-8",
    )
    monkeypatch.setattr(
        variables,
        "inference_endpoints_path",
        path,
    )
    return path


def test_model_service_uses_dedicated_gpu_vms(
    configuration: Configuration,
    variables: Variables,
    http_client: httpx.AsyncClient,
    inference_endpoints: Path,
) -> None:
    assert isinstance(
        NeuralModelServiceFactory.create(
            http_client,
            [_MODEL],
            variables=variables,
            http_config=configuration.server.inference,
        ),
        InferenceService,
    )


def test_model_service_replaces_a_legacy_route_with_generation(
    configuration: Configuration,
    variables: Variables,
    http_client: httpx.AsyncClient,
    inference_endpoints: Path,
) -> None:
    inference_endpoints.write_text(
        json.dumps(
            {_MODEL.id: "http://10.0.0.11:8100/v1/conclusion_generation"},
        ),
        encoding="utf-8",
    )

    service = NeuralModelServiceFactory.create(
        http_client,
        [_MODEL],
        variables=variables,
        http_config=configuration.server.inference,
    )

    assert isinstance(
        service,
        InferenceService,
    )
    assert service._urls[_MODEL.id] == "http://10.0.0.11:8100/v1/generation"


def test_startup_fails_without_an_inference_map(
    configuration: Configuration,
    variables: Variables,
    http_client: httpx.AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Real inference requires a GPU map regardless of the configuration environment.
    monkeypatch.setattr(
        variables,
        "inference_endpoints_path",
        None,
    )

    with pytest.raises(
        RuntimeError,
    ):
        NeuralModelServiceFactory.create(
            http_client,
            [_MODEL],
            variables=variables,
            http_config=configuration.server.inference,
        )


def test_startup_fails_when_available_model_has_no_vm(
    configuration: Configuration,
    variables: Variables,
    http_client: httpx.AsyncClient,
    inference_endpoints: Path,
) -> None:
    inference_endpoints.write_text(
        "{}",
        encoding="utf-8",
    )

    with pytest.raises(
        RuntimeError,
        match="No GPU VM configured for available models",
    ):
        NeuralModelServiceFactory.create(
            http_client,
            [_MODEL],
            variables=variables,
            http_config=configuration.server.inference,
        )


def test_coming_soon_model_does_not_need_a_vm(
    configuration: Configuration,
    variables: Variables,
    http_client: httpx.AsyncClient,
    inference_endpoints: Path,
) -> None:
    coming_soon = _MODEL.model_copy(
        update={
            "id": "google/coming-soon",
            "accessibility": USExaminationNeuralModelAccessibility.COMING_SOON,
        },
    )

    assert isinstance(
        NeuralModelServiceFactory.create(
            http_client,
            [_MODEL, coming_soon],
            variables=variables,
            http_config=configuration.server.inference,
        ),
        InferenceService,
    )


def test_startup_fails_for_an_invalid_vm_url(
    configuration: Configuration,
    variables: Variables,
    http_client: httpx.AsyncClient,
    inference_endpoints: Path,
) -> None:
    inference_endpoints.write_text(
        json.dumps(
            {_MODEL.id: "not-a-url"},
        ),
        encoding="utf-8",
    )

    with pytest.raises(
        RuntimeError,
        match="Invalid GPU VM URL",
    ):
        NeuralModelServiceFactory.create(
            http_client,
            [_MODEL],
            variables=variables,
            http_config=configuration.server.inference,
        )


def test_the_same_composition_in_every_environment(
    configuration: Configuration,
    variables: Variables,
    http_client: httpx.AsyncClient,
    inference_endpoints: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # ENVIRONMENT picks a config directory and nothing else: a report is
    # produced by the same services in development as in production. That is what
    # makes testing against a development backend meaningful.
    built: list[type[NeuralModelService]] = []
    for environment in ("development", "production"):
        monkeypatch.setattr(
            variables,
            "environment",
            environment,
        )
        built.append(
            type(
                NeuralModelServiceFactory.create(
                    http_client,
                    [_MODEL],
                    variables=variables,
                    http_config=configuration.server.inference,
                ),
            ),
        )

    assert built[0] is built[1]


def test_mock_service_does_not_need_an_inference_map(
    configuration: Configuration,
    variables: Variables,
    http_client: httpx.AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        variables,
        "model_service_type",
        NeuralModelServiceType.MOCK,
    )
    monkeypatch.setattr(
        variables,
        "inference_endpoints_path",
        None,
    )

    assert isinstance(
        NeuralModelServiceFactory.create(
            http_client,
            [_MODEL],
            variables=variables,
            http_config=configuration.server.inference,
        ),
        MockNeuralModelService,
    )
