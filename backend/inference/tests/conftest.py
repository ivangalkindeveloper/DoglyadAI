from __future__ import annotations

import os

# `app.core.variables` instantiates `Variables()` at import time, which requires
# SERVED_MODEL_ID to be set (there is no default and no env_file is configured).
# Provide it so the app package can be imported under pytest without a real
# `backend/inference/secrets/.env` present.
os.environ.setdefault("SERVED_MODEL_ID", "example/served-model")

import pytest
from fastapi import FastAPI

from app.core.variables import Variables
from app.model.inference_server_config import InferenceServerConfig


@pytest.fixture
def server_config() -> InferenceServerConfig:
    return InferenceServerConfig.model_validate_json((Variables().configuration_directory / "server.json").read_text())


@pytest.fixture
def app() -> FastAPI:
    from app.core.create_app import create_app

    return create_app(Variables())
