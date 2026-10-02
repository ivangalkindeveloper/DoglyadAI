from __future__ import annotations

from dataclasses import dataclass, field

from app.model.ultrasound.us_examination_scan_photo import USExaminationScanPhoto


@dataclass(frozen=True)
class InferenceRequest:
    """Inputs prepared by the main backend for one inference request."""

    model_id: str
    system_prompt: str
    prompt: str
    structured_output: str
    temperature: float | None = None
    max_tokens: int | None = None
    photos: list[USExaminationScanPhoto] = field(default_factory=list)
    app_check_token: str | None = None
    request_id: str | None = None
