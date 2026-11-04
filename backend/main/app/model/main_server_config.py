from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.model.billing.billing_service_config import BillingServiceConfig
from app.model.email_config import EmailConfig
from app.model.endpoint_config import EndpointConfig
from app.model.http_client_config import HttpClientConfig
from app.model.ultrasound.us_report_generation_config import USReportGenerationConfig
from app.model.ultrasound.us_voice_form_parsing_config import USVoiceFormParsingConfig


class MainServerConfig(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
    )

    report_generation: USReportGenerationConfig = Field(
        default_factory=USReportGenerationConfig,
    )

    endpoints: dict[str, EndpointConfig]
    billing: BillingServiceConfig
    inference: HttpClientConfig
    email: EmailConfig
    voice_form_parsing: USVoiceFormParsingConfig
    max_image_bytes: int = Field(
        gt=0,
    )
    default_max_body_bytes: int = Field(
        gt=0,
    )
