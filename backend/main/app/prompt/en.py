from __future__ import annotations

from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_data import USExaminationData
from app.prompt.base import PromptFactory


class PromptFactoryEn(PromptFactory):
    def system_prompt(
        self,
        settings: NeuralModelSettings,
        include_recommendations: bool,
    ) -> str:
        system_prompt = (
            "You are an AI assistant specialized in generating medical ultrasound examination reports.\n"
            "Produce a report with description — detailed observed structures and findings — and conclusion — "
            "a concise clinical interpretation.\n"
            "Fill the required fields and base them strictly on the provided examination data and images.\n"
            "Do not infer, assume, or fabricate any findings that are not supported by the input.\n"
            "Use precise medical terminology appropriate for a formal radiology report.\n"
            "If the provided data is insufficient to assess a specific structure, state that it was not adequately "
            "visualized rather than speculating.\n"
        )

        if include_recommendations:
            system_prompt += (
                "Also generate recommendations with justified treatment or follow-up actions. "
                "Do not propose actions that are not supported by the provided data.\n"
            )
        else:
            system_prompt += "Do not generate or include recommendations.\n"

        if settings.maxTokens is not None:
            system_prompt += (
                f"Keep the answer within {settings.maxTokens} tokens and finish the report "
                "before reaching this limit so that it is not truncated.\n"
            )

        if not settings.isMarkdown:
            system_prompt += "Fill the string fields with plain text and without Markdown tags.\n"

        return system_prompt

    def build_prompt(
        self,
        examination: USExaminationData,
        examination_title: str,
        template: str | None = None,
    ) -> str:
        prompt = (
            f"Ultrasound examination type: {examination_title}\n"
            f"Examination number: {examination.examinationNumber}\n"
            f"Patient name: {examination.patientName}\n"
            f"Patient gender: {examination.patientGender}\n"
            f"Patient date of birth: {examination.patientDateOfBirth.date().isoformat()}\n"
        )

        if examination.patientHeight is not None:
            prompt += f"Patient height: {examination.patientHeight}\n"

        if examination.patientWeight is not None:
            prompt += f"Patient weight: {examination.patientWeight}\n"

        if examination.patientComplaints:
            prompt += f"Patient complaints: {examination.patientComplaints}\n"

        prompt += f"Ultrasound examination description: {examination.examinationDescription}\n"

        if template:
            prompt += f"Report template: {template}\n"

        return prompt
