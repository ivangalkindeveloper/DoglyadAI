from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from app.core.localization.language_code import LanguageCode
from app.core.localization.language_resolver import LanguageResolver
from app.error import NeuralModelUnavailableError, UnknownExaminationTypeError, UnknownNeuralModelError
from app.model.application_locale_config import ApplicationLocaleConfig
from app.model.application_module_config import ApplicationModuleConfig
from app.model.l10n import L10n
from app.model.l10n_response import L10nResponse
from app.model.main_server_config import MainServerConfig
from app.model.ultrasound.us_examination_contextual_strings import USExaminationContextualStrings
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import USExaminationNeuralModelAccessibility
from app.model.ultrasound.us_examination_ready_made_template import USExaminationReadyMadeTemplate
from app.model.ultrasound.us_examination_type import USExaminationType
from app.model.ultrasound.us_examination_type_group import USExaminationTypeGroup
from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization


@dataclass(
    frozen=True,
)
class Configuration:
    server: MainServerConfig
    application: dict[str, Any]
    locale: ApplicationLocaleConfig
    modules: ApplicationModuleConfig
    l10n: L10n
    contextual_strings: USExaminationContextualStrings
    neural_models: dict[str, USExaminationNeuralModel]
    examination_types: dict[str, USExaminationType]
    examination_type_groups: list[USExaminationTypeGroup]
    ready_made_templates: list[USExaminationReadyMadeTemplate]
    application_localizations: dict[LanguageCode, L10nResponse]
    voice_source_localizations: dict[LanguageCode, USVoiceSourceLocalization]

    @property
    def photo_max_count(
        self,
    ) -> int:
        return int(
            self.application["ultrasound"]["scanPhotoMaxNumber"],
        )

    def language(
        self,
        accept_language: str | None,
    ) -> LanguageCode:
        return LanguageResolver.resolve(
            accept_language,
            self.locale,
        )

    def text(
        self,
        language_code: LanguageCode,
        key: str,
    ) -> str:
        return self.l10n.text(
            language_code,
            key,
        )

    def voice_source_localization(
        self,
        language_code: LanguageCode,
    ) -> USVoiceSourceLocalization:
        return self.voice_source_localizations[language_code]

    def resolve_neural_model(
        self,
        selected_id: str | None,
    ) -> USExaminationNeuralModel:
        if not selected_id:
            model = next(
                iter(
                    self.neural_models.values(),
                ),
            )
        else:
            selected_model = self.neural_models.get(
                selected_id,
            )
            if not selected_model:
                raise UnknownNeuralModelError()
            model = selected_model

        if model.accessibility is not USExaminationNeuralModelAccessibility.AVAILABLE:
            raise NeuralModelUnavailableError()
        return model

    def resolve_examination_title(
        self,
        type_id: str,
        language_code: LanguageCode,
    ) -> str:
        if type_id not in self.examination_types:
            raise UnknownExaminationTypeError()
        return self.l10n.text(
            language_code,
            self.examination_types[type_id].titleLocaleKey,
        )

    def resolve_examination_contextual_strings(
        self,
        type_id: str,
        language_code: LanguageCode,
    ) -> list[str]:
        self.resolve_examination_title(
            type_id,
            language_code,
        )
        return self.contextual_strings.for_type(
            language_code,
            type_id,
        )
