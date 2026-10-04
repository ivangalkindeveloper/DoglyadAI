from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any

from evaluation.voice.common import CONFIG_DIR, ROOT, load_catalog
from evaluation.voice import (
    freeform_holdout_v4,
    freeform_holdout_v5,
    freeform_holdout_v6,
    freeform_holdout_v7,
    freeform_holdout_v8,
)
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.prepare_ios import FIXTURE_DIR, SOURCE_FILES

AUDIO_MODE = "freeform-holdout-v4-text"
AUDIO_MODE_V5 = "freeform-holdout-v5-text"
AUDIO_MODE_V6 = "freeform-holdout-v6-text"
AUDIO_MODE_V7 = "freeform-holdout-v7-text"
AUDIO_MODE_V8 = "freeform-holdout-v8-text"
HOLDOUTS = {
    4: (freeform_holdout_v4.SPLIT, freeform_holdout_v4.write_cases, AUDIO_MODE),
    5: (freeform_holdout_v5.SPLIT, freeform_holdout_v5.write_cases, AUDIO_MODE_V5),
    6: (freeform_holdout_v6.SPLIT, freeform_holdout_v6.write_cases, AUDIO_MODE_V6),
    7: (freeform_holdout_v7.SPLIT, freeform_holdout_v7.write_cases, AUDIO_MODE_V7),
    8: (freeform_holdout_v8.SPLIT, freeform_holdout_v8.write_cases, AUDIO_MODE_V8),
}


def prepare_holdout_fixtures(*, locale: str, version: int = 4, destination: Path = FIXTURE_DIR) -> dict[str, Any]:
    if locale not in ("en", "ru"):
        raise ValueError("Holdout locale must be en or ru")
    if version not in HOLDOUTS:
        raise ValueError("Unknown holdout version")
    split, write_cases, audio_mode = HOLDOUTS[version]
    manifest = write_cases()
    corpus_path = TEXT_OUTPUT_DIR / f"{split}.jsonl"
    cases = [json.loads(line) for line in corpus_path.read_text(encoding="utf-8").splitlines()]
    selected = [case for case in cases if case["locale"] == locale]
    if len(selected) * 2 != len(cases):
        raise ValueError("Holdout locale is incomplete")
    _, terms = load_catalog()
    strings_path = CONFIG_DIR / locale / "l10n.json"
    strings = json.loads(strings_path.read_text(encoding="utf-8"))
    application_path = CONFIG_DIR / "application.json"
    application = json.loads(application_path.read_text(encoding="utf-8"))
    parameters = application["ultrasound"]["examinationNeuralModel"]
    text_manifest_path = TEXT_OUTPUT_DIR / "manifest.json"
    text_manifest = json.loads(text_manifest_path.read_text(encoding="utf-8"))
    fixture = {
        "schemaVersion": 1,
        "split": split,
        "cases": [
            {
                "id": case["id"],
                "locale": locale,
                "examinationTypeId": case["examinationTypeId"],
                "spokenText": case["spokenText"],
                "contextualStrings": terms[locale][case["examinationTypeId"]],
                "systemPrompt": strings["examinationNeuralModelPrompt"],
                "proposalPrompt": strings["examinationDictationProposalPrompt"],
            }
            for case in selected
        ],
        "measureGold": True,
        "textOnly": True,
        "generation": {
            "temperature": parameters["temperature"],
            "maxTokens": parameters["maxTokens"],
            "maxContextTokens": parameters["maxContextTokens"],
        },
        "regressionSha256": text_manifest["regressionSha256"],
        f"holdoutV{version}Sha256": manifest["corpusSha256"],
        "audioManifestSha256": None,
        "audioMode": audio_mode,
        "audioVariant": None,
        "promptSha256": {locale: file_sha256(CONFIG_DIR / locale / "l10n.json")},
        "contextualStringsSha256": {
            locale: file_sha256(CONFIG_DIR / locale / "l10n_ultrasound_examination_contextual_strings.json")
        },
        "applicationSha256": file_sha256(application_path),
        "sourceFilesSha256": {str(path.relative_to(ROOT)): file_sha256(path) for path in SOURCE_FILES},
        "inputSource": "originalText",
        "replayLexiconApplied": False,
    }
    destination.mkdir(parents=True, exist_ok=True)
    fixture_path = destination / "cases.json"
    temporary = destination / "cases.json.tmp"
    previous_stamp = fixture_path.stat().st_mtime_ns if fixture_path.exists() else 0
    temporary.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, fixture_path)
    stamp = max(time.time_ns(), previous_stamp + 1_000_000_000, destination.stat().st_mtime_ns + 1_000_000_000)
    os.utime(fixture_path, ns=(stamp, stamp))
    os.utime(destination, ns=(stamp, stamp))
    return fixture
