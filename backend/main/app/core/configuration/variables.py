from __future__ import annotations

from pathlib import Path
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict

from app.core.configuration.neural_model_service_type import NeuralModelServiceType


class Variables(BaseSettings):
    model_config = SettingsConfigDict(
        extra="ignore",
    )

    # Selects configuration documents and the matching Robokassa test/live mode.
    # Generation routing and App Check remain identical in both environments.
    environment: Literal["development", "production"]

    config_dir: Path | None = None

    log_dir: Path | None = None
    log_retention_days: int = 365

    # Firebase service account used to verify App Check tokens. Verification is
    # unconditional, including local mock generation.
    firebase_credentials_path: Path | None = None

    # Explicitly selects local fixtures instead of GPU inference, independently
    # of ENVIRONMENT.
    model_service_type: NeuralModelServiceType = NeuralModelServiceType.INFERENCE

    # Each GPU host runs one inference service beside its local vLLM engines.
    # Models on the same host can share a URL in this modelId -> URL map.
    # Required when MODEL_SERVICE_TYPE=inference in every environment.
    inference_endpoints_path: Path | None = None
    email_sender: str | None = None
    email_password: str | None = None
    email_smtp_host: str | None = None
    email_smtp_port: int | None = None

    # Shared by the API and worker to encrypt persisted report jobs and snapshots.
    report_generation_encryption_key: str | None = None

    # Billing credentials never belong in the public application configuration.
    billing_database_url: str | None = None
    robokassa_merchant_login: str | None = None
    robokassa_password1: str | None = None
    robokassa_password2: str | None = None
    robokassa_password3: str | None = None
    robokassa_hash_algorithm: Literal["md5", "sha256", "sha384", "sha512"] = "sha256"
    apple_bundle_id: str = "com.medical.doglyad"
    apple_app_id: int | None = None
    apple_root_certificates_path: Path | None = None
    apple_issuer_id: str | None = None
    apple_key_id: str | None = None
    apple_private_key_path: Path | None = None
    is_apple_sandbox_allowed: bool = False
    # Temporary launch gate: production alone must not enable real charges.
    is_robokassa_live_enabled: bool = False

    @property
    def is_robokassa_test(
        self,
    ) -> bool:
        return self.environment == "development"

    @property
    def configuration_directory(
        self,
    ) -> Path:
        return (
            self.config_dir
            or Path(
                __file__,
            )
            .resolve()
            .parents[3]
            / "config"
        ) / self.environment
