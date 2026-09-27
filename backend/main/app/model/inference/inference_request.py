from __future__ import annotations

from dataclasses import dataclass, field

from app.core.language_code import LanguageCode
from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_scan_photo import USExaminationScanPhoto


@dataclass(frozen=True)
class InferenceRequest:
    """Inputs prepared by the main backend for one inference request."""

    neural_model: USExaminationNeuralModel
    settings: NeuralModelSettings
    language_code: LanguageCode
    system_prompt: str
    prompt: str
    structured_output: str
    photos: list[USExaminationScanPhoto] = field(default_factory=list)
    app_check_token: str | None = None
    request_id: str | None = None
