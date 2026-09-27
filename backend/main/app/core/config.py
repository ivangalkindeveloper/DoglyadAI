from __future__ import annotations

import json
import logging
from copy import deepcopy
from pathlib import Path
from typing import Any

from fastapi import HTTPException

from app.core.language_code import LanguageCode
from app.core.locale import SUPPORTED_LANGUAGES
from app.core.variables import variables
from app.model.application_locale_config import ApplicationLocaleConfig
from app.model.config_localization import L10n
from app.model.ultrasound.us_examination_contextual_strings import USExaminationContextualStrings
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)
from app.model.ultrasound.us_examination_neural_model_response import USExaminationNeuralModelResponse
from app.model.ultrasound.us_examination_ready_made_template import USExaminationReadyMadeTemplate
from app.model.ultrasound.us_examination_ready_made_template_response import (
    USExaminationReadyMadeTemplateResponse,
)
from app.model.ultrasound.us_examination_type import USExaminationType
from app.model.ultrasound.us_examination_type_group import USExaminationTypeGroup
from app.model.ultrasound.us_examination_type_group_response import USExaminationTypeGroupResponse
from app.model.ultrasound.us_examination_type_response import USExaminationTypeResponse

logger = logging.getLogger(__name__)

_CONFIG_BASE = variables.config_dir or (Path(__file__).resolve().parent.parent.parent / "config")
_CONFIG_DIR = _CONFIG_BASE / variables.environment

neural_models: dict[str, USExaminationNeuralModel] = {}
examination_types: dict[str, USExaminationType] = {}
examination_type_groups: list[USExaminationTypeGroup] = []
ready_made_templates: list[USExaminationReadyMadeTemplate] = []

_application_config: dict[str, Any] = {}
_locale_config: ApplicationLocaleConfig | None = None
_l10n: L10n | None = None
_contextual_strings: USExaminationContextualStrings | None = None


def _load_json(path: Path) -> Any:
    if not path.exists():
        raise RuntimeError(f"Config file not found: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise RuntimeError(f"Invalid JSON in config file {path}: {error}") from error


def _load_json_array(path: Path) -> list[dict[str, Any]]:
    data = _load_json(path)
    if not isinstance(data, list) or not all(isinstance(item, dict) for item in data):
        raise RuntimeError(f"Config file {path} must contain an array of objects")
    return data


def _load_json_object(path: Path) -> dict[str, Any]:
    data = _load_json(path)
    if not isinstance(data, dict):
        raise RuntimeError(f"Config file {path} must contain a JSON object")
    return data


def _application_response(application: dict[str, Any], l10n: L10n, language: LanguageCode) -> dict[str, Any]:
    response = deepcopy(application)
    settings = response["ultrasound"]["examinationNeuralModel"]
    if "prompt" in settings:
        raise ValueError("Examination prompt belongs in l10n.json")
    settings["prompt"] = l10n.text(language, settings.pop("promptLocaleKey"))
    return response


def _examination_types_response(
    groups: list[USExaminationTypeGroup],
    l10n: L10n,
    contextual_strings: USExaminationContextualStrings,
    language: LanguageCode,
) -> list[USExaminationTypeGroupResponse]:
    return [
        USExaminationTypeGroupResponse(
            id=group.id,
            title=l10n.text(language, group.titleLocaleKey),
            examinationTypes=[
                USExaminationTypeResponse(
                    id=item.id,
                    title=l10n.text(language, item.titleLocaleKey),
                    contextualStrings=contextual_strings.for_type(language, item.id),
                )
                for item in group.examinationTypes
            ],
        )
        for group in groups
    ]


def _neural_models_response(
    models: list[USExaminationNeuralModel], l10n: L10n, language: LanguageCode
) -> list[USExaminationNeuralModelResponse]:
    return [
        USExaminationNeuralModelResponse(
            **model.model_dump(mode="json", exclude={"descriptionLocaleKey"}),
            description=l10n.text(language, model.descriptionLocaleKey),
        )
        for model in models
    ]


def _ready_made_templates_response(
    templates: list[USExaminationReadyMadeTemplate], l10n: L10n, language: LanguageCode
) -> list[USExaminationReadyMadeTemplateResponse]:
    return [
        USExaminationReadyMadeTemplateResponse(
            id=template.id,
            examinationType=template.examinationType,
            title=l10n.text(language, template.titleLocaleKey),
            content=l10n.text(language, template.contentLocaleKey),
        )
        for template in templates
    ]


def _check_unique_ids(ids: list[str], kind: str) -> None:
    if len(ids) != len(set(ids)):
        raise ValueError(f"Duplicate {kind} id")


def load_configs() -> None:
    global _l10n, _contextual_strings, _locale_config
    try:
        application = _load_json_object(_CONFIG_DIR / "application.json")
        locale_config = ApplicationLocaleConfig.model_validate(application.get("locale"))
        groups = [
            USExaminationTypeGroup.model_validate(item)
            for item in _load_json_array(_CONFIG_DIR / "ultrasound_examination_types.json")
        ]
        model_configs = [
            USExaminationNeuralModel.model_validate(item)
            for item in _load_json_array(_CONFIG_DIR / "ultrasound_examination_neural_models.json")
        ]
        templates = [
            USExaminationReadyMadeTemplate.model_validate(item)
            for item in _load_json_array(_CONFIG_DIR / "ready_made_templates.json")
        ]
        l10n = L10n.model_validate(
            {
                language: _load_json_object(_CONFIG_DIR / language.value / "l10n.json")
                for language in SUPPORTED_LANGUAGES
            }
        )
        contextual_strings = USExaminationContextualStrings.model_validate(
            {
                language: _load_json_object(
                    _CONFIG_DIR / language.value / "l10n_ultrasound_examination_contextual_strings.json"
                )
                for language in SUPPORTED_LANGUAGES
            }
        )

        types = {item.id: item for group in groups for item in group.examinationTypes}
        models = {item.id: item for item in model_configs}
        _check_unique_ids([group.id for group in groups], "examination group")
        _check_unique_ids([item.id for group in groups for item in group.examinationTypes], "examination type")
        _check_unique_ids([item.id for item in model_configs], "neural model")
        _check_unique_ids([item.id for item in templates], "ready-made template")
        contextual_strings.validate_type_ids(set(types))
        for template in templates:
            if template.examinationType not in types:
                raise ValueError(
                    f"Unknown examination type id for ready-made template {template.id}: {template.examinationType}"
                )

        for language in SUPPORTED_LANGUAGES:
            _application_response(application, l10n, language)
            _examination_types_response(groups, l10n, contextual_strings, language)
            _neural_models_response(model_configs, l10n, language)
            _ready_made_templates_response(templates, l10n, language)
    except Exception as error:
        logger.exception("Failed to load application configs from %s", _CONFIG_DIR)
        raise RuntimeError(f"Failed to load configs from {_CONFIG_DIR}: {error}") from error

    neural_models.clear()
    neural_models.update(models)
    examination_types.clear()
    examination_types.update(types)
    examination_type_groups.clear()
    examination_type_groups.extend(groups)
    ready_made_templates.clear()
    ready_made_templates.extend(templates)
    _application_config.clear()
    _application_config.update(application)
    _locale_config = locale_config
    _l10n = l10n
    _contextual_strings = contextual_strings


def _catalog() -> L10n:
    if _l10n is None:
        raise RuntimeError("Localizations have not been loaded")
    return _l10n


def get_application_locale_config() -> ApplicationLocaleConfig:
    if _locale_config is None:
        raise RuntimeError("Application locale config has not been loaded")
    return _locale_config


def _contextual_catalog() -> USExaminationContextualStrings:
    if _contextual_strings is None:
        raise RuntimeError("Contextual strings have not been loaded")
    return _contextual_strings


def resolve_application_config_document(language_code: LanguageCode) -> str:
    return json.dumps(_application_response(_application_config, _catalog(), language_code), ensure_ascii=False)


def resolve_examination_types_document(language_code: LanguageCode) -> str:
    response = _examination_types_response(examination_type_groups, _catalog(), _contextual_catalog(), language_code)
    return json.dumps([item.model_dump(mode="json") for item in response], ensure_ascii=False)


def resolve_neural_models_document(language_code: LanguageCode) -> str:
    response = _neural_models_response(list(neural_models.values()), _catalog(), language_code)
    return json.dumps([item.model_dump(mode="json") for item in response], ensure_ascii=False)


def resolve_ready_made_templates(language_code: LanguageCode) -> list[USExaminationReadyMadeTemplateResponse]:
    return _ready_made_templates_response(ready_made_templates, _catalog(), language_code)


def resolve_neural_model(selected_id: str | None) -> USExaminationNeuralModel:
    if not selected_id:
        model = next(iter(neural_models.values()))
    else:
        selected_model = neural_models.get(selected_id)
        if not selected_model:
            raise HTTPException(
                status_code=400,
                detail=f"Unknown neural model id: {selected_id}",
            )
        model = selected_model

    if model.accessibility is not USExaminationNeuralModelAccessibility.AVAILABLE:
        raise HTTPException(
            status_code=400,
            detail=f"Neural model is not available: {model.id}",
        )
    return model


def resolve_examination_title(type_id: str, language_code: LanguageCode) -> str:
    if type_id not in examination_types:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown examination type id: {type_id}",
        )
    return _catalog().text(language_code, examination_types[type_id].titleLocaleKey)
