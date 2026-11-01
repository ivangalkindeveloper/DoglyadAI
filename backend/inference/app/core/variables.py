from __future__ import annotations

from collections.abc import Iterable
from pathlib import Path
from typing import Any, Self

from pydantic import AnyHttpUrl, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

from app.model.non_blank_string import NonBlankString


class Variables(BaseSettings):
    model_config = SettingsConfigDict(
        extra="ignore",
    )

    # No ENVIRONMENT here on purpose: unlike backend/main there are no per-environment
    # configs to choose between. Model routes belong to this inference host.

    log_dir: Path | None = None
    log_retention_days: int = 365

    # App Check is verified here, on the inference service itself: it is the component that
    # actually holds the model, and it must not trust callers just because they can
    # reach it over the network. Verification is unconditional — there is no flag to
    # turn it off, so the credentials are required for the service to start.
    firebase_credentials_path: Path | None = None

    # Existing single-model hosts retain their scalar configuration. Multi-model
    # hosts supply VLLM_ENDPOINTS as a JSON map and clear SERVED_MODEL_ID.
    served_model_id: NonBlankString | None = None
    vllm_endpoints: dict[NonBlankString, AnyHttpUrl] | None = None

    # Local vLLM OpenAI-compatible server, reachable only from inside the VM's
    # Docker network — it is never exposed publicly.
    vllm_base_url: AnyHttpUrl = AnyHttpUrl(
        "http://vllm:8000",
    )
    config_dir: Path | None = None

    @property
    def model_endpoints(
        self,
    ) -> dict[str, str]:
        if self.vllm_endpoints is not None:
            return {
                model_id: str(
                    url,
                ).rstrip(
                    "/",
                )
                for model_id, url in self.vllm_endpoints.items()
            }
        if self.served_model_id is None:
            raise ValueError(
                "An inference model configuration is required",
            )
        return {
            self.served_model_id: str(
                self.vllm_base_url,
            ).rstrip(
                "/",
            )
        }

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
            .parents[2]
            / "config"
        )

    @field_validator(
        "served_model_id",
        mode="before",
    )
    @classmethod
    def clear_empty_model_id(
        cls,
        value: Any,
    ) -> Any:
        # Compose can explicitly clear a legacy value inherited from env_file.
        return None if value == "" else value

    @model_validator(
        mode="after",
    )
    def validate_model_routes(
        self,
    ) -> Self:
        urls: Iterable[AnyHttpUrl]
        if self.vllm_endpoints is not None:
            if not self.vllm_endpoints or self.served_model_id is not None:
                raise ValueError(
                    "Set nonempty VLLM_ENDPOINTS and clear SERVED_MODEL_ID",
                )
            urls = self.vllm_endpoints.values()
        else:
            if self.served_model_id is None:
                raise ValueError(
                    "Set SERVED_MODEL_ID or VLLM_ENDPOINTS",
                )
            urls = [self.vllm_base_url]
        for url in urls:
            if (
                url.username is not None
                or url.password is not None
                or url.query is not None
                or url.fragment is not None
            ):
                raise ValueError(
                    "vLLM URLs must not contain credentials, query strings or fragments",
                )
        return self
