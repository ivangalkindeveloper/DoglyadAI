from __future__ import annotations

from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_data import USExaminationData
from app.prompt.base import PromptFactory


class PromptFactoryRu(PromptFactory):
    def system_prompt(
        self,
        settings: NeuralModelSettings,
    ) -> str:
        prompt = (
            "Ты — AI-ассистент, специализирующийся на создании протоколов ультразвуковых исследований.\n"
            "Твоя задача — формировать подробные клинические заключения, на которые врачи опираются при диагностике и планировании лечения.\n"
            "Заключение должно быть максимально подробным и полным, основываясь на предоставленных данных исследования и изображениях.\n"
            "Используй медицинскую терминологию, принятую для официального УЗИ-заключения.\n"
            "Если предоставленных данных недостаточно для оценки определённой структуры, укажи, что она не была адекватно визуализирована, не строй предположения.\n"
        )

        if settings.maxTokens is not None:
            prompt += (
                f"Уложи ответ максимум в {settings.maxTokens} токенов и заверши заключение "
                "до достижения этого лимита, чтобы оно не оборвалось.\n"
            )

        if not settings.isMarkdown:
            prompt += f"Дай ответ сплошным текстом и без Markdown тегов.\n"

        return prompt

    def build_prompt(
        self,
        examination: USExaminationData,
        examination_title: str,
        template: str | None = None,
    ) -> str:
        prompt = (
            f"Тип ультразвукового исследования: {examination_title}\n"
            f"Имя пациента: {examination.patientName}\n"
            f"Пол пациента: {examination.patientGender}\n"
            f"Дата рождения пациента: {examination.patientDateOfBirth.date().isoformat()}\n"
            f"Рост пациента: {examination.patientHeight}\n"
            f"Вес пациента: {examination.patientWeight}\n"
            f"Жалобы пациента: {examination.patientComplaint}\n"
            f"Описание ультразвукового исследования: {examination.examinationDescription}\n"
        )

        if template:
            prompt += f"Шаблон ответа: {template}\n"

        return prompt
