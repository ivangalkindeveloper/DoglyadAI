from __future__ import annotations

import json
from copy import deepcopy
from typing import Any

from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.model.ultrasound.us_examination_neural_model_response import USExaminationNeuralModelResponse
from app.model.ultrasound.us_examination_ready_made_template_response import USExaminationReadyMadeTemplateResponse
from app.model.ultrasound.us_examination_type_group_response import USExaminationTypeGroupResponse
from app.model.ultrasound.us_examination_type_response import USExaminationTypeResponse
from app.service.validation.text_length_validator import TextLengthValidator


class ConfigurationResponseService:
    def __init__(
        self,
        configuration: Configuration,
    ) -> None:
        self._configuration = configuration

    def validate(
        self,
    ) -> None:
        for language in LanguageCode:
            self.application(
                language,
            )
            self.examination_types(
                language,
            )
            self.neural_models(
                language,
            )
            modules = self._configuration.modules
            for template in self.ready_made_templates(
                language,
            ):
                if not TextLengthValidator.is_within_limit(
                    template.title,
                    min(
                        modules.templateAdd.nameMaxLength,
                        modules.templateEdit.nameMaxLength,
                    ),
                ) or not TextLengthValidator.is_within_limit(
                    template.content,
                    min(
                        modules.templateAdd.contentMaxLength,
                        modules.templateEdit.contentMaxLength,
                    ),
                ):
                    raise ValueError(
                        "Ready-made template exceeds a module input limit",
                    )

    def application_document(
        self,
        language: LanguageCode,
    ) -> str:
        return json.dumps(
            self.application(
                language,
            ),
            ensure_ascii=False,
        )

    def examination_types_document(
        self,
        language: LanguageCode,
    ) -> str:
        return json.dumps(
            [
                value.model_dump(
                    mode="json",
                )
                for value in self.examination_types(
                    language,
                )
            ],
            ensure_ascii=False,
        )

    def neural_models_document(
        self,
        language: LanguageCode,
    ) -> str:
        return json.dumps(
            [
                value.model_dump(
                    mode="json",
                )
                for value in self.neural_models(
                    language,
                )
            ],
            ensure_ascii=False,
        )

    def l10n_document(
        self,
        language: LanguageCode,
    ) -> str:
        return self._configuration.application_localizations[language].model_dump_json()

    def application(
        self,
        language: LanguageCode,
    ) -> dict[str, Any]:
        response = deepcopy(
            self._configuration.application,
        )
        settings = response["ultrasound"]["examinationNeuralModel"]
        if "prompt" in settings or "proposalPrompt" in settings:
            raise ValueError(
                "Examination prompts belong in l10n.json",
            )
        settings["prompt"] = self._configuration.l10n.text(
            language,
            settings.pop(
                "promptLocaleKey",
            ),
        )
        settings["proposalPrompt"] = self._configuration.l10n.text(
            language,
            settings.pop(
                "proposalPromptLocaleKey",
            ),
        )
        return response

    def examination_types(
        self,
        language: LanguageCode,
    ) -> list[USExaminationTypeGroupResponse]:
        return [
            USExaminationTypeGroupResponse(
                id=group.id,
                title=self._configuration.l10n.text(
                    language,
                    group.titleLocaleKey,
                ),
                examinationTypes=[
                    USExaminationTypeResponse(
                        id=item.id,
                        title=self._configuration.l10n.text(
                            language,
                            item.titleLocaleKey,
                        ),
                        contextualStrings=self._configuration.contextual_strings.for_type(
                            language,
                            item.id,
                        ),
                    )
                    for item in group.examinationTypes
                ],
            )
            for group in self._configuration.examination_type_groups
        ]

    def neural_models(
        self,
        language: LanguageCode,
    ) -> list[USExaminationNeuralModelResponse]:
        return [
            USExaminationNeuralModelResponse(
                **model.model_dump(
                    mode="json",
                    exclude={"descriptionLocaleKey"},
                ),
                description=self._configuration.l10n.text(
                    language,
                    model.descriptionLocaleKey,
                ),
            )
            for model in list(
                self._configuration.neural_models.values(),
            )
        ]

    def ready_made_templates(
        self,
        language: LanguageCode,
    ) -> list[USExaminationReadyMadeTemplateResponse]:
        return [
            USExaminationReadyMadeTemplateResponse(
                id=template.id,
                examinationType=template.examinationType,
                title=self._configuration.l10n.text(
                    language,
                    template.titleLocaleKey,
                ),
                content=self._configuration.l10n.text(
                    language,
                    template.contentLocaleKey,
                ),
            )
            for template in self._configuration.ready_made_templates
        ]
