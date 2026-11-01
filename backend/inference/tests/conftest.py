from __future__ import annotations

import os

# Provide the single-model configuration for existing fixtures without reading
# a real secrets file. Multi-model tests supply explicit settings instead.
os.environ.setdefault(
    "SERVED_MODEL_ID",
    "example/served-model",
)

import pytest
from fastapi import FastAPI

from app.core.variables import Variables
from app.model.inference_server_config import InferenceServerConfig


@pytest.fixture
def server_config() -> InferenceServerConfig:
    return InferenceServerConfig.model_validate_json(
        (Variables().configuration_directory / "server.json").read_text(),
    )


@pytest.fixture
def app() -> FastAPI:
    from app.core.create_app import create_app

    return create_app(
        Variables(),
    )
