from __future__ import annotations

from app.core.language_code import LanguageCode
from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_data import USExaminationData


class FakePromptFactory:
    def __init__(self, language_code: LanguageCode) -> None:
        assert language_code is LanguageCode.EN

    def system_prompt(
        self,
        settings: NeuralModelSettings,
        include_recommendations: bool,
        is_photo_remarks: bool,
        is_description_remarks: bool,
    ) -> str:
        assert settings.selectedNeuralModelId == "google/medgemma-4b-it"
        assert include_recommendations is True
        assert is_photo_remarks is False
        assert is_description_remarks is True
        return "system prompt"

    def build_prompt(
        self,
        examination: USExaminationData,
        examination_title: str,
        template: str | None = None,
    ) -> str:
        assert examination.examinationNumber == "Examination#0"
        assert examination.patientName == "Patient"
        assert examination.patientComplaints == "Complaint"
        assert examination_title == "Echocardiography"
        assert template == "Template"
        return "user prompt"
