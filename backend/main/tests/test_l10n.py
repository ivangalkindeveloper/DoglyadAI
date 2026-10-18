from __future__ import annotations

import json
import re
import shutil
from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

import app.core.load_configs as config
from app.core.get_application_locale_config import get_application_locale_config
from app.core.http_header import HttpHeader
from app.core.language_code import LanguageCode
from app.core.resolve_language import SUPPORTED_LANGUAGES
from app.core.verify_app_check import verify_app_check
from app.main import app
from app.prompt.voice_form_system_prompt import voice_form_system_prompt

_ROOT = Path(__file__).resolve().parents[3]
_CONFIG = _ROOT / "backend/main/config"


def _json(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    assert isinstance(value, dict)
    return value


def _swift_cases(path: Path) -> set[str]:
    return set(re.findall(r"^\s*case (\w+)\s*$", path.read_text(encoding="utf-8"), re.MULTILINE))


def _swift_properties(path: Path) -> set[str]:
    return set(re.findall(r"(?:public|private) let (\w+):", path.read_text(encoding="utf-8")))


@pytest.fixture
def localized_client() -> Iterator[TestClient]:
    config.load_configs()

    async def allow_app_check() -> None:
        return None

    app.dependency_overrides[verify_app_check] = allow_app_check
    test_client = TestClient(app)
    try:
        yield test_client
    finally:
        test_client.close()
        app.dependency_overrides.pop(verify_app_check, None)


@pytest.mark.parametrize("header", ["en", "en-US", "ru", "ru-RU", "fr", None])
def test_l10n_returns_only_the_selected_language(localized_client: TestClient, header: str | None) -> None:
    headers = {} if header is None else {HttpHeader.ACCEPT_LANGUAGE.value: header}
    response = localized_client.get("/v1/l10n", headers=headers)
    language = LanguageCode.RU if header and header.startswith("ru") else get_application_locale_config().defaultCode
    if header and header.startswith("en"):
        language = LanguageCode.EN
    directory = config._CONFIG_DIR / language.value
    assert response.status_code == 200
    assert response.json() == {
        "code": language.value,
        "strings": _json(directory / "l10n_application.json"),
        "voice": _json(directory / "l10n_voice_parsing.json"),
    }
    assert response.headers[HttpHeader.CONTENT_LANGUAGE.value] == language.value
    assert response.headers[HttpHeader.VARY.value] == HttpHeader.ACCEPT_LANGUAGE.value


def test_l10n_requires_app_check() -> None:
    client = TestClient(app)  # No lifespan: missing token is rejected before resolving config.
    try:
        response = client.get("/v1/l10n")
    finally:
        client.close()
    assert response.status_code == 401


@pytest.mark.parametrize("environment", ["development", "production"])
def test_catalogs_match_client_contract(environment: str, monkeypatch: pytest.MonkeyPatch) -> None:
    directory = _CONFIG / environment
    monkeypatch.setattr(config, "_CONFIG_DIR", directory)
    config.load_configs()
    app_keys = _swift_cases(_ROOT / "ios/Doglyad/Application/Application/L10N/L10NKey.swift")
    neural = _ROOT / "ios/DoglyadNeuralModel"
    dictation = neural / "UltrasoundExamination/Localization"
    pattern_keys = _swift_cases(dictation / "DNeuralUltrasoundDictationLocalizationKey.swift")
    for language in SUPPORTED_LANGUAGES:
        folder = directory / language.value
        strings = _json(folder / "l10n_application.json")
        assert set(strings) == app_keys, f"UI enum/catalog key drift in {environment}/{language.value}"
        assert all(
            re.fullmatch(
                r"button[A-Z][A-Za-z0-9]*|[a-z][A-Za-z0-9]*(?:Title|Label|Description|Button|Placeholder)", key
            )
            for key in strings
        ), f"UI localization key naming violates the contract in {environment}/{language.value}"
        voice = _json(folder / "l10n_voice_parsing.json")
        assert set(voice) == {"code", "dictation", "speech"}
        assert voice["code"] == language.value
        rules = voice["dictation"]
        assert isinstance(rules, dict)
        assert set(rules) == _swift_properties(dictation / "DNeuralUltrasoundDictationLocalization.swift")
        assert set(rules["patterns"]) == pattern_keys
        assert set(rules["numbers"]) == _swift_properties(
            neural / "Localization/DNeuralDictationNumberLocalization.swift"
        )
        assert set(rules["shortUnits"]) == _swift_properties(
            neural / "Localization/DNeuralDictationShortUnitLocalization.swift"
        )
        assert set(rules["schema"]) == _swift_properties(dictation / "DNeuralUltrasoundSchemaLocalization.swift")
        assert set(voice["speech"]) == _swift_properties(
            _ROOT / "ios/DoglyadSpeech/Audio/DSpeechLexiconLocalization.swift"
        )


def test_client_bundles_only_bootstrap_localization() -> None:
    resources = _ROOT / "ios/Doglyad/Resources"
    assert not list((resources / "Localization").rglob("*.json"))
    strings = _json(resources / "Localizable.xcstrings")["strings"]
    for key in ("", "%@"):
        if key in strings:
            assert not strings[key].get("localizations"), "Technical extraction keys must not contain translations"
    assert set(strings) - {"", "%@"} == {
        "buttonUpdate",
        "errorNoInternetConnectionTitle",
        "errorNoInternetConnectionDescription",
        "errorUnknownTitle",
        "errorUnknownDescription",
        "serviceUnavailableTitle",
        "serviceUnavailableDescription",
        "newVersionTitle",
        "newVersionUpdateDescription",
        "newVersionAvailabilityDescription",
    }
    fixtures = _ROOT / "ios/DoglyadTests/LocalizationFixtures"
    for language in SUPPORTED_LANGUAGES:
        for kind, name in (("voice", "l10n_voice_parsing"), ("strings", "l10n_application")):
            assert (fixtures / f"{kind}-{language.value}.json").resolve() == (
                _CONFIG / "development" / language.value / f"{name}.json"
            )


@pytest.mark.parametrize(
    ("defect", "message"),
    [
        ("missing_key", "Application localization keys differ"),
        ("empty_text", "non-empty keys and translations"),
        ("placeholder", "Localization placeholders differ"),
        ("voice_language", "Voice catalog language must match"),
        ("voice_structure", "Voice localization structure differs"),
        ("number_array", "20 ones"),
    ],
)
def test_startup_rejects_broken_l10n(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, defect: str, message: str
) -> None:
    shutil.copytree(_CONFIG / "development", tmp_path, dirs_exist_ok=True)
    file_name = (
        "l10n_application.json" if defect in {"missing_key", "empty_text", "placeholder"} else "l10n_voice_parsing.json"
    )
    path = tmp_path / LanguageCode.RU.value / file_name
    catalog = _json(path)
    if defect == "missing_key":
        del catalog["buttonSpeech"]
    elif defect == "empty_text":
        catalog["buttonSpeech"] = " "
    elif defect == "placeholder":
        catalog["photoViewPageLabel"] = "{current} / {unknown}"
    elif defect == "voice_language":
        catalog["code"] = LanguageCode.EN.value
    elif defect == "voice_structure":
        del catalog["dictation"]["patterns"]["patientNameLabel"]
    else:
        catalog["dictation"]["numbers"]["ones"].pop()
    path.write_text(json.dumps(catalog, ensure_ascii=False), encoding="utf-8")
    monkeypatch.setattr(config, "_CONFIG_DIR", tmp_path)
    with pytest.raises(RuntimeError, match=message):
        config.load_configs()


@pytest.mark.parametrize("environment", ["development", "production"])
@pytest.mark.parametrize("language", list(LanguageCode))
def test_voice_prompt_uses_selected_server_catalog(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, environment: str, language: LanguageCode
) -> None:
    shutil.copytree(_CONFIG / environment, tmp_path, dirs_exist_ok=True)
    expected = f"Voice extraction instructions: {environment}/{language.value}"
    correction = f"Medical terminology instructions: {environment}/{language.value}"
    path = tmp_path / language.value / "l10n.json"
    catalog = _json(path)
    catalog["voiceFormSystemPrompt"] = expected
    catalog["medicalTermCorrectionPrompt"] = correction
    path.write_text(json.dumps(catalog, ensure_ascii=False), encoding="utf-8")
    monkeypatch.setattr(config, "_CONFIG_DIR", tmp_path)
    config.load_configs()

    assert voice_form_system_prompt(language) == expected + " " + correction


@pytest.mark.parametrize(
    ("translation", "message"),
    [
        (None, "Missing localization key: voiceFormSystemPrompt"),
        (" ", "Expected non-empty localized text: voiceFormSystemPrompt"),
        ("Instructions with {unknown}", "Prompt localization placeholders differ: voiceFormSystemPrompt"),
    ],
)
def test_startup_rejects_broken_voice_prompt(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, translation: str | None, message: str
) -> None:
    shutil.copytree(_CONFIG / "development", tmp_path, dirs_exist_ok=True)
    languages = list(LanguageCode) if translation is None else [LanguageCode.RU]
    for language in languages:
        path = tmp_path / language.value / "l10n.json"
        catalog = _json(path)
        if translation is None:
            del catalog["voiceFormSystemPrompt"]
        else:
            catalog["voiceFormSystemPrompt"] = translation
        path.write_text(json.dumps(catalog, ensure_ascii=False), encoding="utf-8")
    monkeypatch.setattr(config, "_CONFIG_DIR", tmp_path)

    with pytest.raises(RuntimeError, match=message):
        config.load_configs()
