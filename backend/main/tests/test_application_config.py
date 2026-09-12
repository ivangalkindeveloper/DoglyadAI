from __future__ import annotations

import json
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.core.config import _CONFIG_DIR, load_configs
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)

# Endpoint -> the document in the image it must serve, byte for byte.
_ENDPOINTS = {
    "/v1/application_config": "application.json",
    "/v1/ultrasound/examination_types": "ultrasound_examination_types.json",
    "/v1/ultrasound/examination_neural_models": "ultrasound_examination_neural_models.json",
    "/v1/ultrasound/examination_contextual_strings": "ultrasound_examination_contextual_strings.json",
}


@pytest.fixture(scope="module")
def client() -> Iterator[TestClient]:
    # The documents are read once at startup, so they have to be loaded before the
    # routes are exercised. TestClient runs without the lifespan on purpose: the
    # lifespan also initializes App Check, which needs Firebase credentials.
    load_configs()
    from app.core.app_check import verify_app_check
    from app.main import app

    async def allow_app_check() -> None:
        return None

    app.dependency_overrides[verify_app_check] = allow_app_check
    test_client = TestClient(app)
    yield test_client
    test_client.close()
    app.dependency_overrides.pop(verify_app_check, None)


@pytest.mark.parametrize("path", _ENDPOINTS)
def test_document_is_served_as_json(client: TestClient, path: str) -> None:
    response = client.get(path)

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("application/json")
    json.loads(response.text)


@pytest.mark.parametrize(("path", "document"), _ENDPOINTS.items())
def test_served_bytes_match_the_file_in_the_image(client: TestClient, path: str, document: str) -> None:
    # Served verbatim rather than parsed and re-serialized: the app must receive
    # exactly what shipped, down to key order and formatting.
    assert client.get(path).text == (_CONFIG_DIR / document).read_text(encoding="utf-8")


@pytest.mark.parametrize("path", _ENDPOINTS)
def test_config_is_protected_by_app_check(client: TestClient, path: str) -> None:
    from app.core.app_check import verify_app_check

    route = next(r for r in client.app.routes if getattr(r, "path", None) == path)
    dependencies = [call.call for call in route.dependant.dependencies]  # type: ignore[attr-defined]
    assert verify_app_check in dependencies


def test_only_the_app_facing_documents_are_exposed(client: TestClient) -> None:
    served = {str(getattr(r, "path", "")) for r in client.app.routes}
    assert set(_ENDPOINTS) <= served
    assert "/application_config" not in served
    assert "/ultrasound/application_config" not in served
    assert "/ultrasound/examination_types" not in served
    assert "/ultrasound/examination_neural_models" not in served
    assert "/ultrasound/examination_contextual_strings" not in served
    assert "/ultrasound_examination_types" not in served


@pytest.mark.parametrize("environment", ("development", "production"))
def test_service_availability_is_the_first_boolean_field(environment: str) -> None:
    path = _CONFIG_DIR.parent / environment / "application.json"
    application_config = json.loads(path.read_text(encoding="utf-8"))

    assert next(iter(application_config)) == "isServiceAvailable"
    assert isinstance(application_config["isServiceAvailable"], bool)


@pytest.mark.parametrize("environment", ("development", "production"))
def test_neural_model_accessibility_is_valid_and_the_default_is_available(environment: str) -> None:
    path = _CONFIG_DIR.parent / environment / "ultrasound_examination_neural_models.json"
    neural_models = json.loads(path.read_text(encoding="utf-8"))

    accessibility = [USExaminationNeuralModelAccessibility(model["accessibility"]) for model in neural_models]

    assert accessibility
    assert accessibility[0] is USExaminationNeuralModelAccessibility.AVAILABLE


@pytest.mark.parametrize("environment", ("development", "production"))
def test_examination_types_are_grouped_and_unique(environment: str) -> None:
    path = _CONFIG_DIR.parent / environment / "ultrasound_examination_types.json"
    groups = json.loads(path.read_text(encoding="utf-8"))

    assert groups
    assert all(group["id"] and group["title"] and group["examinationTypes"] for group in groups)
    type_ids = [item["id"] for group in groups for item in group["examinationTypes"]]
    assert len(type_ids) == len(set(type_ids))
