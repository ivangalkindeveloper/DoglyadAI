from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from evaluation.voice.common import ROOT
from evaluation.voice.generate import file_sha256


def prepare(output: Path, fixtures: Path) -> None:
    from app.core.language_code import LanguageCode
    from app.core.load_configs import load_configs
    from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
    from app.prompt.voice_form_prompt import voice_form_prompt
    from app.prompt.voice_form_system_prompt import voice_form_system_prompt

    load_configs()
    rows: list[dict[str, Any]] = []
    for case in json.loads(fixtures.read_text(encoding="utf-8")):
        language = LanguageCode(case["locale"])
        rows.append(
            {
                **case,
                "pack": "free-speech-control",
                "scenario": "free-speech-control",
                "inputVersion": fixtures.stem,
                "systemPrompt": voice_form_system_prompt(language),
                "prompt": voice_form_prompt(
                    "Ультразвуковое исследование" if language is LanguageCode.RU else "Ultrasound examination",
                    case["inputText"],
                    [],
                ),
                "schema": json.loads(USVoiceFormGeneration.structured_output()),
            }
        )
    if len({row["id"] for row in rows}) != len(rows):
        raise ValueError("Duplicate control case IDs")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows), encoding="utf-8")
    sources = [
        ROOT / "backend/main/app/service" / name
        for name in (
            "clinical_value_is_supported.py",
            "examination_number_markers.py",
            "gender_from_evidence.py",
            "has_birth_date_cue.py",
            "has_content_outside_evidence.py",
            "has_examination_number_evidence.py",
            "labeled_birth_date.py",
            "labeled_clinical_text.py",
            "labeled_examination_number.py",
            "labeled_measurement.py",
            "labeled_patient_gender.py",
            "patient_name_metadata_evidence.py",
            "repair_patient_name_evidence.py",
            "source_birth_date.py",
            "source_measurement.py",
            "source_number.py",
            "source_year.py",
            "validate_voice_form_generation.py",
        )
    ]
    manifest = {
        "fixturesSha256": file_sha256(fixtures),
        "casesSha256": file_sha256(output),
        "expectedFields": sum(len(row["expectedFields"]) for row in rows),
        "cases": len(rows),
        "sourcesSha256": {path.name: file_sha256(path) for path in sources},
        "promptSha256": file_sha256(ROOT / "backend/main/app/prompt/voice_form_system_prompt.py"),
        "inputsAndGoldSha256": hashlib.sha256(
            json.dumps(rows, ensure_ascii=False, sort_keys=True).encode("utf-8")
        ).hexdigest(),
    }
    (output.parent / f"{output.stem}-frozen.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    snapshot = output.parent / f"{output.stem}-sources"
    snapshot.mkdir(exist_ok=True)
    for path in sources:
        (snapshot / path.name).write_bytes(path.read_bytes())
    print(f"Frozen {len(rows)} cases / {manifest['expectedFields']} fields: {output}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--fixtures", type=Path, default=ROOT / "evaluation/voice/fixtures/free_speech_control.json")
    args = parser.parse_args()
    prepare(args.output, args.fixtures)


if __name__ == "__main__":
    main()
