from __future__ import annotations

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Variables(BaseSettings):
    model_config = SettingsConfigDict(extra="ignore")

    # No ENVIRONMENT here on purpose: unlike backend/main there are no per-environment
    # configs to choose between. This service only talks to the model next to it, and
    # which model that is comes from SERVED_MODEL_ID.

    log_dir: Path | None = None
    log_retention_days: int = 365

    # App Check is verified here, on the inference service itself: it is the component that
    # actually holds the model, and it must not trust callers just because they can
    # reach it over the network. Verification is unconditional — there is no flag to
    # turn it off, so the credentials are required for the service to start.
    firebase_credentials_path: Path | None = None

    # The single model this GPU VM serves. One VM per model, so this is a scalar and
    # not a map: a request for any other model id is rejected rather than silently
    # answered by the wrong model.
    served_model_id: str

    # Local vLLM OpenAI-compatible server, reachable only from inside the VM's
    # Docker network — it is never exposed publicly.
    vllm_base_url: str = "http://vllm:8000"
    # The innermost timeout of the chain, so it has to stay under the backend's
    # INFERENCE_REQUEST_TIMEOUT_SECONDS (130). Set it higher and the backend hangs
    # up on a generation this service is still running: the GPU time is spent and
    # the result is thrown away.
    vllm_request_timeout_seconds: int = 120


variables = Variables()
