from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from evaluation.voice.audio.audio import add_reproducible_noise, wav_metadata
from evaluation.voice.common import CONFIG_DIR, ROOT
from evaluation.voice.audio.end_to_end import synthesize_rows
from evaluation.voice.datasets.generate import file_sha256


def prepare_terminology_matrix(output: Path) -> dict[str, Any]:
    """Cover every unique contextual phrase; do not fabricate clinical findings."""
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    sources: dict[str, str] = {}
    rows: list[dict[str, Any]] = []
    coverage: dict[str, Any] = {}
    for locale in ("ru", "en"):
        source = CONFIG_DIR / locale / "l10n_ultrasound_examination_contextual_strings.json"
        catalog = json.loads(source.read_text(encoding="utf-8"))
        sources[str(source.relative_to(ROOT))] = file_sha256(source)
        seen: set[str] = set()
        phrase_cases: dict[str, str] = {}
        for type_id, phrases in catalog.items():
            unique = []
            for phrase in phrases:
                if phrase not in seen:
                    unique.append(phrase)
                    seen.add(phrase)
            for index in range(0, len(unique), 8):
                terms = unique[index : index + 8]
                case_id = f"terms-{locale}-{type_id}-{index // 8:02d}"
                description = "; ".join(terms) + "."
                label = "Описание исследования" if locale == "ru" else "Examination description"
                text = label + ": " + description
                rows.append(
                    {
                        "id": case_id,
                        "pack": "terminology",
                        "locale": locale,
                        "examinationTypeId": type_id,
                        "inputText": text,
                        "spokenText": text,
                        "expectedFields": {"examinationDescription": description},
                        "terms": terms,
                        "category": "terminology",
                    }
                )
                phrase_cases.update({term: case_id for term in terms})
        if set(phrase_cases) != {term for phrases in catalog.values() for term in phrases}:
            raise ValueError("Terminology coverage is incomplete")
        coverage[locale] = {
            "uniquePhrases": len(seen),
            "catalogOccurrences": sum(map(len, catalog.values())),
            "phraseCases": phrase_cases,
        }
    source = output / "terms-input.json"
    if source.exists():
        if json.loads(source.read_text(encoding="utf-8")) != rows:
            raise ValueError("Frozen terminology input differs")
    else:
        source.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if not (output / "cases.json").exists():
        synthesize_rows(rows, output=output, fixture=source, manifest_name="matrix-terminology")
    manifest = json.loads((output / "cases.json").read_text(encoding="utf-8"))
    if manifest["fixtureSha256"] != file_sha256(source):
        raise ValueError("Frozen terminology source hash differs")
    cases: list[dict[str, Any]] = []
    for row in manifest["cases"]:
        clean = output / row["audioFile"]
        if file_sha256(clean) != row["audioSha256"]:
            raise ValueError("Terminology audio changed")
        noisy = output / "noisy" / clean.name
        if not noisy.exists():
            add_reproducible_noise(clean, noisy, row["id"])
        for variant, path in (("clean", clean), ("noisy", noisy)):
            audio = wav_metadata(path)
            cases.append(
                {
                    "id": f"terminology/{row['id']}/{variant}",
                    "caseId": row["id"],
                    "mode": "terminology",
                    "variant": variant,
                    "locale": row["locale"],
                    "audioPath": str(path.relative_to(ROOT)),
                    "audioSha256": audio["sha256"],
                    "durationSeconds": audio["durationSeconds"],
                    "referenceText": row["spokenText"],
                    "inputText": row["inputText"],
                    "examinationTypeId": row["examinationTypeId"],
                    "expectedFields": row["expectedFields"],
                    "expectedFacts": [],
                    "scenario": "terminology",
                    "terms": row["terms"],
                }
            )
    result = {"schemaVersion": 1, "sources": sources, "coverage": coverage, "cases": cases}
    (output / "matrix.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="Freeze a TTS corpus covering every ultrasound contextual phrase")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    manifest = prepare_terminology_matrix(args.output)
    print(f"Terminology WAV: {len(manifest['cases'])}")
    print(json.dumps({locale: group["uniquePhrases"] for locale, group in manifest["coverage"].items()}))


if __name__ == "__main__":
    main()
