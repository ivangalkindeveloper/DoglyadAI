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
    texts = _document(_CONFIG_DIR, "l10n.json")[language]
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
                    "contextualStrings": texts[source_item["contextualStringsLocaleKey"]],
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


@pytest.mark.parametrize(
    ("header", "expected"),
    (
        ("ru_RU", "ru"),
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
    catalog = _document(_CONFIG_DIR, "l10n.json")
    for language in ("ru", "en"):
        response = client.get("/v1/templates/ready_made_list", headers={"Accept-Language": language})
        assert response.status_code == 200
        assert response.headers["content-language"] == language
        assert response.headers["vary"] == "Accept-Language"
        _assert_no_source_keys(response.json())
        for item, original in zip(response.json(), source, strict=True):
            assert item == {
                "id": original["id"],
                "examinationType": original["examinationType"],
                "title": catalog[language][original["titleLocaleKey"]],
                "content": catalog[language][original["contentLocaleKey"]],
            }


def test_examination_types_have_distinct_speech_terms(client: TestClient) -> None:
    groups = client.get("/v1/ultrasound/examination_types", headers={"Accept-Language": "ru"}).json()
    terms_by_type = {item["id"]: item["contextualStrings"] for group in groups for item in group["examinationTypes"]}
    assert "почечная лоханка" in terms_by_type["kidneysAdrenalGlandsAndRetroperitonealSpace"]
    assert "почечная лоханка" not in terms_by_type["echocardiography"]
    assert "митральный клапан" in terms_by_type["echocardiography"]
    assert "митральный клапан" not in terms_by_type["kidneysAdrenalGlandsAndRetroperitonealSpace"]


@pytest.mark.parametrize("environment", ("development", "production"))
def test_config_references_one_complete_l10n_catalog(environment: str) -> None:
    directory = _CONFIG_DIR.parent / environment
    application = _document(directory, "application.json")
    groups = _document(directory, "ultrasound_examination_types.json")
    models = _document(directory, "ultrasound_examination_neural_models.json")
    templates = _document(directory, "ready_made_templates.json")
    catalog = _document(directory, "l10n.json")

    assert set(catalog) == {"en", "ru"}
    assert set(catalog["en"]) == set(catalog["ru"])
    for name in (
        "application_localizations.json",
        "ultrasound_examination_types_localizations.json",
        "ultrasound_examination_neural_models_localizations.json",
        "ready_made_templates_localizations.json",
    ):
        assert not (directory / name).exists()

    references: dict[str, set[str]] = {}
    for path in directory.glob("*.json"):
        if path.name != "l10n.json":
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

    assert refs == set(catalog["en"])
    contextual_keys = references["contextualStringsLocaleKey"]
    text_keys = set().union(*(keys for field, keys in references.items() if field != "contextualStringsLocaleKey"))
    assert not contextual_keys & text_keys
    assert USExaminationNeuralModelAccessibility(models[0]["accessibility"]) is (
        USExaminationNeuralModelAccessibility.AVAILABLE
    )
    for language in ("ru", "en"):
        for key, value in catalog[language].items():
            if key in contextual_keys:
                assert isinstance(value, list)
                assert len(value) == 50
                assert all(phrase.strip() and len(phrase.split()) <= 3 for phrase in value)
                assert len(value) == len({phrase.strip().casefold() for phrase in value})
            else:
                assert isinstance(value, str) and value.strip()


@pytest.mark.parametrize("defect", ("new_type_without_keys", "translation_missing_in_ru"))
def test_startup_rejects_incomplete_localization(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, defect: str) -> None:
    for name in (*_ENDPOINTS.values(), "ready_made_templates.json", "l10n.json"):
        shutil.copyfile(_CONFIG_DIR / name, tmp_path / name)

    if defect == "new_type_without_keys":
        path = tmp_path / "ultrasound_examination_types.json"
        groups = _document(tmp_path, path.name)
        groups[0]["examinationTypes"].append(
            {
                "id": "newExaminationType",
                "titleLocaleKey": "newExaminationTypeTitle",
                "contextualStringsLocaleKey": "newExaminationTypeContextualStrings",
            }
        )
        path.write_text(json.dumps(groups, ensure_ascii=False), encoding="utf-8")
        expected_error = "Missing localization key: newExaminationTypeTitle"
    else:
        path = tmp_path / "l10n.json"
        catalog = _document(tmp_path, path.name)
        del catalog["ru"]["echocardiographyTitle"]
        path.write_text(json.dumps(catalog, ensure_ascii=False), encoding="utf-8")
        expected_error = "Localization keys differ"

    monkeypatch.setattr(config_module, "_CONFIG_DIR", tmp_path)
    with pytest.raises(RuntimeError, match=expected_error):
        load_configs()
