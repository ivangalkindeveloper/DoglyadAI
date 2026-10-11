from __future__ import annotations

from dataclasses import dataclass, field

from app.core.language_code import LanguageCode
from app.model.neural_model.neural_model_service_operation import NeuralModelServiceOperation
from app.model.ultrasound.us_examination_scan_photo import USExaminationScanPhoto


@dataclass(frozen=True)
class NeuralModelServiceRequest:
    """Inputs prepared by the main backend for one model-service operation."""

    operation: NeuralModelServiceOperation
    language_code: LanguageCode
    model_id: str
    system_prompt: str
    prompt: str
    structured_output: str
    temperature: float | None = None
    max_tokens: int | None = None
    photos: list[USExaminationScanPhoto] = field(default_factory=list)
    app_check_token: str | None = None
    request_id: str | None = None
