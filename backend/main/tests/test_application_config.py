from __future__ import annotations

import json
import shutil
from collections.abc import Iterator
from copy import deepcopy
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

import app.core.config as config_module
from app.core.config import _CONFIG_DIR, load_configs
from app.core.locale import SUPPORTED_LANGUAGES, resolve_language
from app.model.application_locale_config import ApplicationLocaleConfig
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)

_ENDPOINTS = {
    "/v1/application_config": "application.json",
    "/v1/ultrasound/examination_types": "ultrasound_examination_types.json",
    "/v1/ultrasound/examination_neural_models": "ultrasound_examination_neural_models.json",
}


def _document(directory: Path, name: str) -> object:
    return json.loads((directory / name).read_text(encoding="utf-8"))


def _locale_document(directory: Path, language: str, name: str) -> dict[str, object]:
    document = _document(directory / language, name)
    assert isinstance(document, dict)
    return document


def _assert_no_source_keys(value: object) -> None:
    if isinstance(value, dict):
        assert not {"en", "ru"}.issubset(value)
        assert all(not key.endswith("LocaleKey") for key in value)
        for child in value.values():
            _assert_no_source_keys(child)
    elif isinstance(value, list):
        for child in value:
            _assert_no_source_keys(child)


def _collect_locale_references(value: object, references: dict[str, set[str]]) -> None:
    if isinstance(value, dict):
        for field, child in value.items():
            if field.endswith("LocaleKey"):
                assert isinstance(child, str) and child
                references.setdefault(field, set()).add(child)
            else:
                _collect_locale_references(child, references)
    elif isinstance(value, list):
        for child in value:
            _collect_locale_references(child, references)


@pytest.fixture(scope="module")
def client() -> Iterator[TestClient]:
    # The test client skips lifespan because Firebase credentials are not available here.
    load_configs()
    from app.core.app_check import verify_app_check
    from app.main import app

    async def allow_app_check() -> None:
        return None

    app.dependency_overrides[verify_app_check] = allow_app_check
    test_client = TestClient(app)
    yield test_client
    test_client.close()
    app.dependency_overrides.pop(verify_app_check, None)


@pytest.mark.parametrize(("path", "source_file"), _ENDPOINTS.items())
@pytest.mark.parametrize("language", ("en", "ru"))
def test_config_document_resolves_locale_keys(client: TestClient, path: str, source_file: str, language: str) -> None:
    response = client.get(path, headers={"Accept-Language": f"{language}-US"})
    source = _document(_CONFIG_DIR, source_file)
    texts = _locale_document(_CONFIG_DIR, language, "l10n.json")
    contextual_strings = _locale_document(_CONFIG_DIR, language, "l10n_ultrasound_examination_contextual_strings.json")
    result = response.json()
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("application/json")
    assert response.headers["content-language"] == language
    assert response.headers["vary"] == "Accept-Language"
    _assert_no_source_keys(result)

    if path.endswith("application_config"):
        expected = deepcopy(source)
        settings = expected["ultrasound"]["examinationNeuralModel"]
        settings["prompt"] = texts[settings.pop("promptLocaleKey")]
        assert result == expected
    elif path.endswith("examination_types"):
        assert [group["id"] for group in result] == [group["id"] for group in source]
        for group, original in zip(result, source, strict=True):
            assert group["title"] == texts[original["titleLocaleKey"]]
            for item, source_item in zip(group["examinationTypes"], original["examinationTypes"], strict=True):
                assert item == {
                    "id": source_item["id"],
                    "title": texts[source_item["titleLocaleKey"]],
                    "contextualStrings": contextual_strings[source_item["id"]],
                }
    else:
        for item, original in zip(result, source, strict=True):
            expected = {key: value for key, value in original.items() if key != "descriptionLocaleKey"}
            expected["description"] = texts[original["descriptionLocaleKey"]]
            assert item == expected


def test_missing_or_unsupported_language_defaults_to_english(client: TestClient) -> None:
    for headers in ({}, {"Accept-Language": "fr-FR"}):
        response = client.get("/v1/ultrasound/examination_types", headers=headers)
        assert response.headers["content-language"] == "en"
        assert isinstance(response.json()[0]["title"], str)


def test_language_selection_uses_configured_default_and_codes() -> None:
    locale_config = ApplicationLocaleConfig(defaultCode="ru", codes=["ru"])
    assert resolve_language(None, locale_config).value == "ru"
    assert resolve_language("fr-FR, en-US", locale_config).value == "ru"
    assert resolve_language("ru-RU, en-US", locale_config).value == "ru"


def test_application_config_response_uses_configured_default(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    application = deepcopy(config_module._application_config)
    application["locale"]["defaultCode"] = "ru"
    monkeypatch.setattr(config_module, "_application_config", application)
    monkeypatch.setattr(
        config_module,
        "_locale_config",
        ApplicationLocaleConfig(defaultCode="ru", codes=["en", "ru"]),
    )
    response = client.get("/v1/application_config", headers={"Accept-Language": "fr-FR"})
    ru_texts = _locale_document(_CONFIG_DIR, "ru", "l10n.json")
    prompt_key = _document(_CONFIG_DIR, "application.json")["ultrasound"]["examinationNeuralModel"]["promptLocaleKey"]

    assert response.headers["content-language"] == "ru"
    assert response.json()["locale"]["defaultCode"] == "ru"
    assert response.json()["ultrasound"]["examinationNeuralModel"]["prompt"] == ru_texts[prompt_key]


@pytest.mark.parametrize(
    ("header", "expected"),
    (
        ("ru_RU", "ru"),
        ("fr-FR, ru-RU, en-US", "ru"),
        ("en-US,en;q=0.9,ru;q=0.8", "en"),
        ("fr,ru-RU;q=0.9,en;q=0.4", "ru"),
        ("ru;q=0,en;q=0.5", "en"),
    ),
)
def test_accept_language_priority(client: TestClient, header: str, expected: str) -> None:
    assert (
        client.get("/v1/application_config", headers={"Accept-Language": header}).headers["content-language"]
        == expected
    )


@pytest.mark.parametrize("path", (*_ENDPOINTS, "/v1/templates/ready_made_list"))
def test_config_is_protected_by_app_check(client: TestClient, path: str) -> None:
    from app.core.app_check import verify_app_check

    route = next(r for r in client.app.routes if getattr(r, "path", None) == path)
    dependencies = [call.call for call in route.dependant.dependencies]  # type: ignore[attr-defined]
    assert verify_app_check in dependencies


def test_only_the_app_facing_documents_are_exposed(client: TestClient) -> None:
    served = {str(getattr(route, "path", "")) for route in client.app.routes}
    assert set(_ENDPOINTS) <= served
    assert "/v1/ultrasound/examination_contextual_strings" not in served
    assert "/application_config" not in served
    assert "/ultrasound/examination_types" not in served


def test_ready_made_templates_resolve_locale_keys(client: TestClient) -> None:
    source = _document(_CONFIG_DIR, "ready_made_templates.json")
    for language in ("ru", "en"):
        texts = _locale_document(_CONFIG_DIR, language, "l10n.json")
        response = client.get("/v1/templates/ready_made_list", headers={"Accept-Language": language})
        assert response.status_code == 200
        assert response.headers["content-language"] == language
        assert response.headers["vary"] == "Accept-Language"
        _assert_no_source_keys(response.json())
        for item, original in zip(response.json(), source, strict=True):
            assert item == {
                "id": original["id"],
                "examinationType": original["examinationType"],
                "title": texts[original["titleLocaleKey"]],
                "content": texts[original["contentLocaleKey"]],
            }


def test_examination_types_have_distinct_speech_terms(client: TestClient) -> None:
    groups = client.get("/v1/ultrasound/examination_types", headers={"Accept-Language": "ru"}).json()
    terms_by_type = {item["id"]: item["contextualStrings"] for group in groups for item in group["examinationTypes"]}
    assert "почечная лоханка" in terms_by_type["kidneysAdrenalGlandsAndRetroperitonealSpace"]
    assert "почечная лоханка" not in terms_by_type["echocardiography"]
    assert "митральный клапан" in terms_by_type["echocardiography"]
    assert "митральный клапан" not in terms_by_type["kidneysAdrenalGlandsAndRetroperitonealSpace"]


@pytest.mark.parametrize("environment", ("development", "production"))
def test_config_references_complete_locale_catalogs(environment: str) -> None:
    directory = _CONFIG_DIR.parent / environment
    application = _document(directory, "application.json")
    groups = _document(directory, "ultrasound_examination_types.json")
    models = _document(directory, "ultrasound_examination_neural_models.json")
    templates = _document(directory, "ready_made_templates.json")
    texts = {language: _locale_document(directory, language, "l10n.json") for language in ("en", "ru")}
    contextual_strings = {
        language: _locale_document(directory, language, "l10n_ultrasound_examination_contextual_strings.json")
        for language in ("en", "ru")
    }

    assert not (directory / "l10n.json").exists()
    assert application["locale"]["defaultCode"] in application["locale"]["codes"]
    assert set(application["locale"]["codes"]) == {language.value for language in SUPPORTED_LANGUAGES}
    assert set(texts["en"]) == set(texts["ru"])
    assert set(contextual_strings["en"]) == set(contextual_strings["ru"])
    for name in (
        "application_localizations.json",
        "ultrasound_examination_types_localizations.json",
        "ultrasound_examination_neural_models_localizations.json",
        "ready_made_templates_localizations.json",
    ):
        assert not (directory / name).exists()

    references: dict[str, set[str]] = {}
    for path in directory.glob("*.json"):
        _collect_locale_references(_document(directory, path.name), references)
    refs = set().union(*references.values())
    assert "prompt" not in application["ultrasound"]["examinationNeuralModel"]
    group_ids = [group["id"] for group in groups]
    type_ids = [item["id"] for group in groups for item in group["examinationTypes"]]
    model_ids = [model["id"] for model in models]
    template_ids = [template["id"] for template in templates]
    assert type_ids
    for ids in (group_ids, type_ids, model_ids, template_ids):
        assert len(ids) == len(set(ids))

    assert all("description" not in model for model in models)
    assert all(template["examinationType"] in set(type_ids) for template in templates)

    assert refs == set(texts["en"])
    assert "contextualStringsLocaleKey" not in references
    assert USExaminationNeuralModelAccessibility(models[0]["accessibility"]) is (
        USExaminationNeuralModelAccessibility.AVAILABLE
    )
    for language in ("ru", "en"):
        assert set(contextual_strings[language]) == set(type_ids)
        for value in texts[language].values():
            assert isinstance(value, str) and value.strip()
        for value in contextual_strings[language].values():
            assert isinstance(value, list)
            assert 1 <= len(value) <= 100
            assert all(isinstance(phrase, str) and phrase.strip() and len(phrase.split()) <= 3 for phrase in value)
            assert len(value) == len({phrase.strip().casefold() for phrase in value})


@pytest.mark.parametrize(
    "defect",
    (
        "new_type_without_keys",
        "new_type_without_title_translation",
        "translation_missing_in_ru",
        "contextual_strings_missing_in_ru",
        "contextual_strings_unknown_type",
        "invalid_contextual_strings",
        "unsupported_application_locale",
        "default_application_locale_not_supported",
    ),
)
def test_startup_rejects_incomplete_localization(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, defect: str) -> None:
    for name in (*_ENDPOINTS.values(), "ready_made_templates.json"):
        shutil.copyfile(_CONFIG_DIR / name, tmp_path / name)
    for language in ("en", "ru"):
        (tmp_path / language).mkdir()
        for name in ("l10n.json", "l10n_ultrasound_examination_contextual_strings.json"):
            shutil.copyfile(_CONFIG_DIR / language / name, tmp_path / language / name)

    if defect == "unsupported_application_locale":
        path = tmp_path / "application.json"
        application = _document(tmp_path, path.name)
        application["locale"]["codes"] = ["en", "fr"]
        path.write_text(json.dumps(application, ensure_ascii=False), encoding="utf-8")
        expected_error = "Input should be 'en' or 'ru'"
    elif defect == "default_application_locale_not_supported":
        path = tmp_path / "application.json"
        application = _document(tmp_path, path.name)
        application["locale"]["codes"] = ["ru"]
        path.write_text(json.dumps(application, ensure_ascii=False), encoding="utf-8")
        expected_error = "Application locale defaultCode must be included in codes"
    elif defect in ("new_type_without_keys", "new_type_without_title_translation"):
        path = tmp_path / "ultrasound_examination_types.json"
        groups = _document(tmp_path, path.name)
        groups[0]["examinationTypes"].append(
            {
                "id": "newExaminationType",
                "titleLocaleKey": "newExaminationTypeTitle",
            }
        )
        path.write_text(json.dumps(groups, ensure_ascii=False), encoding="utf-8")
        if defect == "new_type_without_title_translation":
            for language in ("en", "ru"):
                locale_path = tmp_path / language / "l10n_ultrasound_examination_contextual_strings.json"
                locale_catalog = _document(locale_path.parent, locale_path.name)
                locale_catalog["newExaminationType"] = ["example"]
                locale_path.write_text(json.dumps(locale_catalog, ensure_ascii=False), encoding="utf-8")
            expected_error = "Missing localization key: newExaminationTypeTitle"
        else:
            expected_error = "Contextual strings do not match examination types"
    elif defect == "translation_missing_in_ru":
        path = tmp_path / "ru" / "l10n.json"
        catalog = _document(path.parent, path.name)
        del catalog["echocardiographyTitle"]
        path.write_text(json.dumps(catalog, ensure_ascii=False), encoding="utf-8")
        expected_error = "Localization keys differ"
    else:
        path = tmp_path / "ru" / "l10n_ultrasound_examination_contextual_strings.json"
        catalog = _document(path.parent, path.name)
        if defect == "contextual_strings_missing_in_ru":
            del catalog["echocardiography"]
            expected_error = "Contextual string type ids differ"
        elif defect == "contextual_strings_unknown_type":
            for language in ("en", "ru"):
                locale_path = tmp_path / language / path.name
                locale_catalog = _document(locale_path.parent, locale_path.name)
                locale_catalog["unknownExaminationType"] = ["example"]
                locale_path.write_text(json.dumps(locale_catalog, ensure_ascii=False), encoding="utf-8")
            expected_error = "Contextual strings do not match examination types"
        else:
            catalog["echocardiography"] = ["same phrase", "same phrase"]
            expected_error = "Empty or duplicate contextual strings"
        if defect != "contextual_strings_unknown_type":
            path.write_text(json.dumps(catalog, ensure_ascii=False), encoding="utf-8")

    monkeypatch.setattr(config_module, "_CONFIG_DIR", tmp_path)
    with pytest.raises(RuntimeError, match=expected_error):
        load_configs()
