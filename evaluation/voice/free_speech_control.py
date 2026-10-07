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
    from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
    from app.prompt.voice_form import voice_form_prompt, voice_form_system_prompt

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
                ),
                "schema": json.loads(USVoiceFormGeneration.structured_output()),
            }
        )
    if len({row["id"] for row in rows}) != len(rows):
        raise ValueError("Duplicate control case IDs")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows), encoding="utf-8")
    sources = sorted((ROOT / "backend/main/app/service").glob("voice_form_*.py"))
    manifest = {
        "fixturesSha256": file_sha256(fixtures),
        "casesSha256": file_sha256(output),
        "expectedFields": sum(len(row["expectedFields"]) for row in rows),
        "cases": len(rows),
        "sourcesSha256": {path.name: file_sha256(path) for path in sources},
        "promptSha256": file_sha256(ROOT / "backend/main/app/prompt/voice_form.py"),
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
