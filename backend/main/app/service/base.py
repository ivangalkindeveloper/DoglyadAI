from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field

from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_scan_photo import USExaminationScanPhoto


@dataclass(frozen=True)
class InferenceRequest:
    """Everything a `ModelService` needs to produce one structured response.

    Grouped into an object rather than passed as positional arguments so the route
    remains independent of the concrete service implementation.
    """

    neural_model: USExaminationNeuralModel
    settings: NeuralModelSettings
    # Resolved from the Accept-Language header. The services get it baked into the
    # prompts already; kept here so a failure can be reported in the right language.
    language_code: str
    system_prompt: str
    prompt: str
    structured_output: str
    photos: list[USExaminationScanPhoto] = field(default_factory=list)
    # The caller's App Check token, already verified at the edge and relayed
    # unchanged to the GPU VM, which verifies it again.
    app_check_token: str | None = None


class ModelService(ABC):
    @abstractmethod
    async def call(self, request: InferenceRequest) -> str:
        """Runs one generation and returns structured content as JSON text."""
        ...
