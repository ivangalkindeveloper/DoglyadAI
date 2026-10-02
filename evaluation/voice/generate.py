from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from evaluation.voice import adversarial, control, regression
from evaluation.voice.common import CONFIG_DIR, ROOT, load_catalog

OUTPUT_DIR = ROOT / "build/voice-eval/text"
SCHEMA_VERSION = 1


def make_corpus() -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    type_ids, terms = load_catalog()
    regression_cases = [
        case
        for locale in ("en", "ru")
        for type_id in type_ids
        for case in regression.generate_cases(locale, type_id, terms)
    ]
    control_cases = [
        case
        for locale in ("en", "ru")
        for type_id in type_ids
        for case in control.generate_cases(locale, type_id, terms)
    ]
    return regression_cases, control_cases


def jsonl_bytes(cases: list[dict[str, Any]]) -> bytes:
    return ("\n".join(json.dumps(case, ensure_ascii=False, sort_keys=True) for case in cases) + "\n").encode("utf-8")


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_corpus(output: Path = OUTPUT_DIR, *, release_control: bool = False) -> dict[str, Any]:
    regression_cases, control_cases = make_corpus()
    adversarial_cases = adversarial.generate_cases()
    regression_data = jsonl_bytes(regression_cases)
    control_data = jsonl_bytes(control_cases)
    adversarial_data = jsonl_bytes(adversarial_cases)
    output.mkdir(parents=True, exist_ok=True)
    existing_manifest_path = output / "manifest.json"
    existing_manifest = (
        json.loads(existing_manifest_path.read_text(encoding="utf-8")) if existing_manifest_path.exists() else None
    )
    control_hash = hashlib.sha256(control_data).hexdigest()
    if existing_manifest is not None and existing_manifest.get("controlSha256") != control_hash:
        raise ValueError("Reserved control set changed; create a new corpus version instead")
    if (output / "control.jsonl").exists() and file_sha256(output / "control.jsonl") != control_hash:
        raise ValueError("Released control set differs from its reserved hash")
    control_released = release_control or (output / "control.jsonl").exists()
    (output / "regression.jsonl").write_bytes(regression_data)
    (output / "adversarial.jsonl").write_bytes(adversarial_data)
    if release_control:
        (output / "control.jsonl").write_bytes(control_data)

    source_files = [
        CONFIG_DIR / "ultrasound_examination_types.json",
        *(CONFIG_DIR / locale / "l10n_ultrasound_examination_contextual_strings.json" for locale in ("en", "ru")),
    ]
    manifest = {
        "schemaVersion": SCHEMA_VERSION,
        "generator": "evaluation.voice.v1",
        "regressionCases": len(regression_cases),
        "controlCases": len(control_cases),
        "adversarialCases": len(adversarial_cases),
        "regressionSha256": hashlib.sha256(regression_data).hexdigest(),
        "controlSha256": control_hash,
        "adversarialSha256": hashlib.sha256(adversarial_data).hexdigest(),
        "controlReleased": control_released,
        "sources": {str(path.relative_to(ROOT)): file_sha256(path) for path in source_files},
    }
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate deterministic synthetic voice-form cases")
    parser.add_argument("--output", type=Path, default=OUTPUT_DIR)
    parser.add_argument(
        "--release-control",
        action="store_true",
        help="Write the reserved control cases for a final comparison only",
    )
    arguments = parser.parse_args()
    manifest = write_corpus(arguments.output, release_control=arguments.release_control)
    print(
        f"Regression: {manifest['regressionCases']} cases; "
        f"adversarial: {manifest['adversarialCases']} cases; "
        f"control reserved: {manifest['controlCases']} cases"
    )
    print(f"Output: {arguments.output}")


if __name__ == "__main__":
    main()
