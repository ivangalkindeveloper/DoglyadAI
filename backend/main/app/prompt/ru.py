from __future__ import annotations

from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_data import USExaminationData
from app.prompt.base import PromptFactory


class PromptFactoryRu(PromptFactory):
    def system_prompt(
        self,
        settings: NeuralModelSettings,
        include_recommendations: bool,
    ) -> str:
        system_prompt = (
            "Ты — AI-ассистент, специализирующийся на создании протоколов ультразвуковых исследований.\n"
            "Сформируй протокол исследования: description — подробное описание наблюдаемых структур и признаков; "
            "conclusion — краткое клиническое заключение.\n"
            "Заполни обязательные поля максимально полно, основываясь только на предоставленных данных "
            "исследования и изображениях.\n"
            "Используй медицинскую терминологию, принятую для официального протокола УЗИ.\n"
            "Если предоставленных данных недостаточно для оценки определённой структуры, укажи, что она не была "
            "адекватно визуализирована, не строй предположения.\n"
        )

        if include_recommendations:
            system_prompt += (
                "Также сформируй recommendations — обоснованные рекомендации по лечению или дальнейшим действиям. "
                "Не предлагай действия, не подтверждённые предоставленными данными.\n"  # noqa: RUF001
            )
        else:
            system_prompt += "Не формируй и не включай рекомендации.\n"  # noqa: RUF001

        if settings.maxTokens is not None:
            system_prompt += (
                f"Уложи ответ максимум в {settings.maxTokens} токенов и заверши протокол "
                "до достижения этого лимита, чтобы он не оборвался.\n"
            )

        if not settings.isMarkdown:
            system_prompt += "Заполняй строковые поля обычным текстом без Markdown-тегов.\n"

        return system_prompt

    def build_prompt(
        self,
        examination: USExaminationData,
        examination_title: str,
        template: str | None = None,
    ) -> str:
        prompt = (
            f"Тип ультразвукового исследования: {examination_title}\n"
            f"Номер исследования: {examination.examinationNumber}\n"
            f"Имя пациента: {examination.patientName}\n"
            f"Пол пациента: {examination.patientGender}\n"
            f"Дата рождения пациента: {examination.patientDateOfBirth.date().isoformat()}\n"
            f"Рост пациента: {examination.patientHeight}\n"
            f"Вес пациента: {examination.patientWeight}\n"  # noqa: RUF001
        )

        if examination.patientComplaint:
            prompt += f"Жалобы пациента: {examination.patientComplaint}\n"

        prompt += f"Описание ультразвукового исследования: {examination.examinationDescription}\n"

        if template:
            prompt += f"Шаблон протокола: {template}\n"

        return prompt
