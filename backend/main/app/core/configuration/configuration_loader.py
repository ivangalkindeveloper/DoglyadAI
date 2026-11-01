from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

from app.core.configuration.configuration import Configuration
from app.core.localization.application_localization_validator import ApplicationLocalizationValidator
from app.core.localization.language_code import LanguageCode
from app.core.localization.language_resolver import LanguageResolver
from app.core.localization.prompt_localization_validator import PromptLocalizationValidator
from app.model.application_locale_config import ApplicationLocaleConfig
from app.model.application_module_config import ApplicationModuleConfig
from app.model.l10n import L10n
from app.model.l10n_response import L10nResponse
from app.model.main_server_config import MainServerConfig
from app.model.ultrasound.us_examination_contextual_strings import USExaminationContextualStrings
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_ready_made_template import USExaminationReadyMadeTemplate
from app.model.ultrasound.us_examination_type_group import USExaminationTypeGroup
from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization
from app.service.configuration.configuration_response_service import ConfigurationResponseService

logger = logging.getLogger(
    __name__,
)


class ConfigurationLoader:
    def __init__(
        self,
        directory: Path,
    ) -> None:
        self._directory = directory

    def load_server(
        self,
    ) -> MainServerConfig:
        return MainServerConfig.model_validate(
            self._load_json_object(
                self._directory / "server.json",
            ),
        )

    def load(
        self,
        server: MainServerConfig | None = None,
    ) -> Configuration:
        try:
            server = server if server is not None else self.load_server()
            application = self._load_json_object(
                self._directory / "application.json",
            )
            locale_config = ApplicationLocaleConfig.model_validate(
                application.get(
                    "locale",
                ),
            )
            modules = ApplicationModuleConfig.model_validate(
                application,
            )
            groups = [
                USExaminationTypeGroup.model_validate(
                    item,
                )
                for item in self._load_json_array(
                    self._directory / "ultrasound_examination_types.json",
                )
            ]
            model_configs = [
                USExaminationNeuralModel.model_validate(
                    item,
                )
                for item in self._load_json_array(
                    self._directory / "ultrasound_examination_neural_models.json",
                )
            ]
            templates = [
                USExaminationReadyMadeTemplate.model_validate(
                    item,
                )
                for item in self._load_json_array(
                    self._directory / "ready_made_templates.json",
                )
            ]
            l10n = L10n.model_validate(
                {
                    language: self._load_json_object(
                        self._directory / language.value / "l10n.json",
                    )
                    for language in LanguageResolver.SUPPORTED_LANGUAGES
                },
            )
            contextual_strings = USExaminationContextualStrings.model_validate(
                {
                    language: self._load_json_object(
                        self._directory / language.value / "l10n_ultrasound_examination_contextual_strings.json",
                    )
                    for language in LanguageResolver.SUPPORTED_LANGUAGES
                },
            )
            application_localizations = {
                language: L10nResponse.model_validate(
                    {
                        "code": language.value,
                        "strings": self._load_json_object(
                            self._directory / language.value / "l10n_application.json",
                        ),
                        "voice": self._load_json_object(
                            self._directory / language.value / "l10n_voice_parsing.json",
                        ),
                    },
                )
                for language in LanguageResolver.SUPPORTED_LANGUAGES
            }
            source_localizations: dict[LanguageCode, USVoiceSourceLocalization] = {}
            for language, catalog in application_localizations.items():
                voice = catalog.voice
                dictation = voice["dictation"]
                speech = voice["speech"]
                if not isinstance(
                    dictation,
                    dict,
                ) or not isinstance(
                    speech,
                    dict,
                ):
                    raise ValueError(
                        "Invalid voice catalog",
                    )
                numbers = dictation["numbers"]
                if not isinstance(
                    numbers,
                    dict,
                ):
                    raise ValueError(
                        "Invalid number catalog",
                    )
                ones, tens, digits = numbers["ones"], numbers["tens"], numbers["digits"]
                if (
                    not isinstance(
                        ones,
                        list,
                    )
                    or not isinstance(
                        tens,
                        list,
                    )
                    or not isinstance(
                        digits,
                        dict,
                    )
                ):
                    raise ValueError(
                        "Invalid number vocabulary",
                    )
                number_words = {
                    word: index
                    for index, word in enumerate(
                        ones,
                    )
                    if isinstance(
                        word,
                        str,
                    )
                    and word
                }
                number_words.update(
                    {
                        word: index * 10
                        for index, word in enumerate(
                            tens,
                        )
                        if isinstance(
                            word,
                            str,
                        )
                        and word
                    },
                )
                number_words.update(
                    {
                        word: int(
                            value,
                        )
                        for word, value in digits.items()
                        if isinstance(
                            value,
                            str,
                        )
                    },
                )
                source_localizations[language] = USVoiceSourceLocalization.model_validate(
                    {
                        **self._load_json_object(
                            self._directory / language.value / "l10n_voice_source_validation.json",
                        ),
                        "numberWords": number_words,
                        "digitWords": digits,
                        "characterReplacements": speech["literalCharacterReplacements"],
                    },
                )
            ApplicationLocalizationValidator.validate(
                application_localizations,
            )
            PromptLocalizationValidator.validate(
                l10n,
            )

            types = {item.id: item for group in groups for item in group.examinationTypes}
            models = {item.id: item for item in model_configs}
            self._check_unique_ids(
                [group.id for group in groups],
                "examination group",
            )
            self._check_unique_ids(
                [item.id for group in groups for item in group.examinationTypes],
                "examination type",
            )
            self._check_unique_ids(
                [item.id for item in model_configs],
                "neural model",
            )
            self._check_unique_ids(
                [item.id for item in templates],
                "ready-made template",
            )
            contextual_strings.validate_type_ids(
                set(
                    types,
                ),
            )
            for template in templates:
                if template.examinationType not in types:
                    raise ValueError(
                        f"Unknown examination type id for ready-made template {template.id}: "
                        f"{template.examinationType}",
                    )

            configuration = Configuration(
                server=server,
                application=application,
                locale=locale_config,
                modules=modules,
                l10n=l10n,
                contextual_strings=contextual_strings,
                neural_models=models,
                examination_types=types,
                examination_type_groups=groups,
                ready_made_templates=templates,
                application_localizations=application_localizations,
                voice_source_localizations=source_localizations,
            )
            if not models:
                raise ValueError(
                    "At least one neural model is required",
                )
            if configuration.photo_max_count <= 0:
                raise ValueError(
                    "scanPhotoMaxNumber must be positive",
                )
            ConfigurationResponseService(
                configuration,
            ).validate()
            return configuration
        except Exception as error:
            logger.exception(
                "Failed to load application configs from %s",
                self._directory,
            )
            raise RuntimeError(
                f"Failed to load configs from {self._directory}: {error}",
            ) from error

    def _load_json(
        self,
        path: Path,
    ) -> Any:
        if not path.exists():
            raise RuntimeError(
                f"Config file not found: {path}",
            )
        try:
            return json.loads(
                path.read_text(
                    encoding="utf-8",
                ),
            )
        except json.JSONDecodeError as error:
            raise RuntimeError(
                f"Invalid JSON in config file {path}: {error}",
            ) from error

    def _load_json_array(
        self,
        path: Path,
    ) -> list[dict[str, Any]]:
        data = self._load_json(
            path,
        )
        if not isinstance(
            data,
            list,
        ) or not all(
            (
                isinstance(
                    item,
                    dict,
                )
                for item in data
            ),
        ):
            raise RuntimeError(
                f"Config file {path} must contain an array of objects",
            )
        return data

    def _load_json_object(
        self,
        path: Path,
    ) -> dict[str, Any]:
        data = self._load_json(
            path,
        )
        if not isinstance(
            data,
            dict,
        ):
            raise RuntimeError(
                f"Config file {path} must contain a JSON object",
            )
        return data

    @staticmethod
    def _check_unique_ids(
        ids: list[str],
        kind: str,
    ) -> None:
        if len(
            ids,
        ) != len(
            set(
                ids,
            ),
        ):
            raise ValueError(
                f"Duplicate {kind} id",
            )
