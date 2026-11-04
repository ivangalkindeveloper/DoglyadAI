"""Use the same synthetic requests for both remaining MedGemma models."""

from __future__ import annotations

import json
from pathlib import Path

DIRECTORY = Path(__file__).resolve().parent
MODELS = {
    "medgemma-15-4b": "google/medgemma-1.5-4b-it",
    "medgemma-27b": "google/medgemma-27b-it",
}


def main() -> None:
    for name, model in MODELS.items():
        destination = DIRECTORY / name
        destination.mkdir(exist_ok=True)
        for variant in ("working", "unbounded-grammar"):
            cases = json.loads((DIRECTORY.parent / "schema-revision" / f"{variant}-cases.json").read_text())
            for case in cases:
                case["model"] = model
                case["payload"]["model"] = model
                case["body"]["settingsAI"]["selectedNeuralModelId"] = model
            (destination / f"{variant}-cases.json").write_text(
                json.dumps(cases, ensure_ascii=False, indent=2) + "\n"
            )
            print(name, variant, len(cases))


if __name__ == "__main__":
    main()
