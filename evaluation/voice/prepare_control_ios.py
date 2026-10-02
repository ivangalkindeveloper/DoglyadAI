from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Literal

from evaluation.voice.common import CONFIG_DIR, ROOT, load_catalog
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.prepare_ios import FIXTURE_DIR, SOURCE_FILES


def _prepare_text_fixtures(split: Literal["control", "adversarial"], *, destination: Path) -> dict[str, Any]:
    corpus_path = TEXT_OUTPUT_DIR / f"{split}.jsonl"
    manifest = json.loads((TEXT_OUTPUT_DIR / "manifest.json").read_text(encoding="utf-8"))
    if split == "control" and (not manifest["controlReleased"] or not corpus_path.exists()):
        raise ValueError("The reserved control set has not been released")
    expected_hash = manifest[f"{split}Sha256"]
    if not corpus_path.exists() or file_sha256(corpus_path) != expected_hash:
        raise ValueError(f"{split} set differs from its reserved hash")
    cases = [json.loads(line) for line in corpus_path.read_text(encoding="utf-8").splitlines()]
    expected_count = 248 if split == "control" else 10
    if len(cases) != expected_count:
        raise ValueError(f"{split} set must contain exactly {expected_count} cases")
    _, terms = load_catalog()
    localizations = {
        locale: json.loads((CONFIG_DIR / locale / "l10n.json").read_text(encoding="utf-8")) for locale in ("en", "ru")
    }
    settings = json.loads((CONFIG_DIR / "application.json").read_text(encoding="utf-8"))["ultrasound"][
        "examinationNeuralModel"
    ]
    fixture: dict[str, Any] = {
        "schemaVersion": 1,
        "split": split,
        "textOnly": True,
        "inputSource": "originalText",
        "controlSha256": manifest["controlSha256"],
        "adversarialSha256": manifest["adversarialSha256"],
        "regressionSha256": manifest["regressionSha256"],
        "generation": {key: settings[key] for key in ("temperature", "maxTokens", "maxContextTokens")},
        "promptSha256": {locale: file_sha256(CONFIG_DIR / locale / "l10n.json") for locale in ("en", "ru")},
        "contextualStringsSha256": {
            locale: file_sha256(CONFIG_DIR / locale / "l10n_ultrasound_examination_contextual_strings.json")
            for locale in ("en", "ru")
        },
        "applicationSha256": file_sha256(CONFIG_DIR / "application.json"),
        "sourceFilesSha256": {str(path.relative_to(ROOT)): file_sha256(path) for path in SOURCE_FILES},
        "cases": [
            {
                "id": case["id"],
                "locale": case["locale"],
                "examinationTypeId": case["examinationTypeId"],
                "spokenText": case["spokenText"],
                "contextualStrings": terms[case["locale"]][case["examinationTypeId"]],
                "systemPrompt": localizations[case["locale"]]["examinationNeuralModelPrompt"],
                "proposalPrompt": localizations[case["locale"]]["examinationDictationProposalPrompt"],
            }
            for case in cases
        ],
    }
    destination.mkdir(parents=True, exist_ok=True)
    (destination / "cases.json").write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return fixture


def prepare_control_fixtures(*, destination: Path = FIXTURE_DIR) -> dict[str, Any]:
    return _prepare_text_fixtures("control", destination=destination)


def prepare_adversarial_fixtures(*, destination: Path = FIXTURE_DIR) -> dict[str, Any]:
    return _prepare_text_fixtures("adversarial", destination=destination)
