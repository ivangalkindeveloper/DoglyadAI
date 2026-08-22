from __future__ import annotations

from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_data import USExaminationData
from app.prompt.base import PromptFactory


class PromptFactoryEn(PromptFactory):
    def system_prompt(self, settings: NeuralModelSettings) -> str:
        prompt = (
            "You are an AI assistant specialized in generating medical ultrasound examination reports.\n"
            "Your task is to write the conclusion of the report — the interpretive summary that physicians rely on for diagnosis and treatment planning.\n"
            "Base it strictly on the provided examination data and images, and output nothing else.\n"
            "Do not infer, assume, or fabricate any findings that are not supported by the input.\n"
            "Use precise medical terminology appropriate for a formal radiology report.\n"
            "If the provided data is insufficient to assess a specific structure, state that it was not adequately visualized rather than speculating.\n"
        )

        if settings.maxTokens is not None:
            prompt += (
                f"Keep the answer within {settings.maxTokens} tokens and finish the conclusion "
                "before reaching this limit so that it is not truncated.\n"
            )

        if not settings.isMarkdown:
            prompt += f"Provide your answer in plain text and without Markdown tags.\n"

        return prompt

    def build_prompt(
        self,
        examination: USExaminationData,
        examination_title: str,
        template: str | None = None,
    ) -> str:
        prompt = (
            f"Ultrasound examination type: {examination_title}\n"
            f"Patient name: {examination.patientName}\n"
            f"Patient gender: {examination.patientGender}\n"
            f"Patient date of birth: {examination.patientDateOfBirth.date().isoformat()}\n"
            f"Patient height: {examination.patientHeight}\n"
            f"Patient weight: {examination.patientWeight}\n"
            f"Patient complaint: {examination.patientComplaint}\n"
            f"Ultrasound examination description: {examination.examinationDescription}\n"
        )

        if template:
            prompt += f"Response template: {template}\n"

        return prompt
