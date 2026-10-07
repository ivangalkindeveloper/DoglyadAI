from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
from typing import Any

from evaluation.voice.common import ROOT
from evaluation.voice.generate import file_sha256
from evaluation.voice.natural_birth_dates import VERSION as NATURAL_DATE_VERSION
from evaluation.voice.natural_birth_dates import natural_date_text
from evaluation.voice.run_server_benchmark import PACKS
from evaluation.voice.server_parse import load_cases, score_response, summarize


def prepare(output: Path, *, natural_dates: bool = False, quality_regressions: bool = False) -> None:
    from app.core.config import load_configs, resolve_examination_title
    from app.core.language_code import LanguageCode
    from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
    from app.prompt.voice_form import voice_form_prompt, voice_form_system_prompt

    load_configs()
    schema = json.loads(USVoiceFormGeneration.structured_output())
    rows: list[dict[str, Any]] = []
    for pack, corpus_name, folder in PACKS:
        cases = load_cases(
            ROOT / "build/voice-eval/text" / f"{corpus_name}.jsonl",
            None,
            ROOT / "build/voice-eval/audio" / folder / "manifest.json",
        )
        date_style_counts = {"en": 0, "ru": 0}
        for case in cases:
            if not case["inputText"]:
                raise ValueError(f"Missing ideal text: {case['id']}")
            language = LanguageCode(case["locale"])
            text = case["inputText"]
            date_style = None
            if natural_dates and "patientDateOfBirth" in case["expectedFields"]:
                spoken = date_style_counts[case["locale"]] % 2 == 0
                date_style_counts[case["locale"]] += 1
                text = natural_date_text(case, spoken=spoken)
                date_style = "spoken" if spoken else "written"
            rows.append(
                {
                    "id": case["id"],
                    "pack": pack,
                    "locale": case["locale"],
                    "scenario": case["scenario"],
                    "expectedFields": case["expectedFields"],
                    "inputText": text,
                    "inputVersion": NATURAL_DATE_VERSION if natural_dates else "legacy-digit-dates-v1",
                    "birthDateStyle": date_style,
                    "systemPrompt": voice_form_system_prompt(language),
                    "prompt": voice_form_prompt(
                        resolve_examination_title(case["examinationTypeId"], language),
                        text,
                    ),
                    "schema": schema,
                }
            )
    if len(rows) != 372 or len({row["id"] for row in rows}) != 372:
        raise ValueError("Expected exactly 372 unique cases")
    for pack, _, _ in PACKS:
        for locale in ("en", "ru"):
            if sum(row["pack"] == pack and row["locale"] == locale for row in rows) != 62:
                raise ValueError(f"Incomplete {pack}/{locale}")
    if quality_regressions:
        fixtures = json.loads(
            (ROOT / "evaluation/voice/fixtures/gpu_quality_regression.json").read_text(encoding="utf-8")
        )
        for fixture in fixtures:
            template = next(row for row in rows if row["locale"] == fixture["locale"])
            rows.append(
                {
                    **template,
                    **fixture,
                    "pack": "quality-regression",
                    "scenario": "quality-regression",
                    "birthDateStyle": None,
                    "prompt": voice_form_prompt(
                        json.loads(template["prompt"])["examinationType"], fixture["inputText"]
                    ),
                }
            )
        if len({row["id"] for row in rows}) != len(rows):
            raise ValueError("Duplicate quality-regression case ID")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows), encoding="utf-8")
    print(f"Prepared {len(rows)} cases in {output}")


def score(
    cases_path: Path, results_path: Path, output_path: Path, *, baseline_validator_path: Path | None = None
) -> None:
    from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
    from app.service.voice_form_validation import validate_voice_form_generation

    validator = validate_voice_form_generation
    validator_path = ROOT / "backend/main/app/service/voice_form_validation.py"
    if baseline_validator_path is not None:
        spec = importlib.util.spec_from_file_location("voice_benchmark_baseline", baseline_validator_path)
        if spec is None or spec.loader is None:
            raise ValueError("Cannot load the frozen baseline validator")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        validator = module.validate_voice_form_generation
        validator_path = baseline_validator_path

    cases = {
        row["id"]: row for line in cases_path.read_text(encoding="utf-8").splitlines() if (row := json.loads(line))
    }
    result_rows = [json.loads(line) for line in results_path.read_text(encoding="utf-8").splitlines()]
    results = {row["id"]: row for row in result_rows}
    if len(results) != len(result_rows):
        raise ValueError("Duplicate result case IDs")
    if set(results) != set(cases):
        raise ValueError(f"Case mismatch: {len(results)} results for {len(cases)} cases")
    scored: list[dict[str, Any]] = []
    for case_id, case in cases.items():
        result = results[case_id]
        row: dict[str, Any] = {
            "id": case_id,
            "pack": case["pack"],
            "locale": case["locale"],
            "scenario": case["pack"],
            "elapsedSeconds": result.get("elapsedSeconds"),
            "status": result["status"],
            "expectedFieldIds": list(case["expectedFields"]),
        }
        if result["status"] == "ok":
            try:
                generated = USVoiceFormGeneration.model_validate_json(result["content"])
                if result.get("finishReason") == "length":
                    raise ValueError("Model output was truncated by the token limit")
                validated = validator(generated, case["inputText"])
                response = validated.model_dump(mode="json")
                row["generatedProposals"] = generated.model_dump(mode="json")
                row["response"] = response
                row["score"] = score_response(case["expectedFields"], response, case["locale"])
            except (ValueError, TypeError, KeyError) as error:
                row["status"] = "validation_error"
                row["error"] = str(error)[:300]
        else:
            row["error"] = result.get("error", "")
        scored.append(row)
    report = {
        "modelId": json.loads(results_path.read_text(encoding="utf-8").splitlines()[0])["modelId"],
        "source": "ideal-text/direct-vllm",
        "casesSha256": file_sha256(cases_path),
        "rawResultsSha256": file_sha256(results_path),
        "validatorSha256": file_sha256(validator_path),
        "validationSourcesSha256": (
            {"baseline_validation.py": file_sha256(validator_path)}
            if baseline_validator_path is not None
            else {
                name: file_sha256(ROOT / "backend/main/app/service" / name)
                for name in (
                    "voice_form_validation.py",
                    "voice_form_number_evidence.py",
                    "voice_form_clinical_text.py",
                    "voice_form_birth_date.py",
                    "voice_form_measurement.py",
                    "voice_form_numbers.py",
                    "voice_form_gender.py",
                    "voice_form_name_evidence.py",
                )
            }
        ),
        "inputsAndGoldSha256": hashlib.sha256(
            json.dumps(
                [
                    {key: case[key] for key in ("id", "pack", "locale", "expectedFields", "inputText", "schema")}
                    for case in cases.values()
                ],
                ensure_ascii=False,
                sort_keys=True,
            ).encode("utf-8")
        ).hexdigest(),
        "inputVersions": sorted({case.get("inputVersion", "legacy-digit-dates-v1") for case in cases.values()}),
        "results": scored,
        "byLocaleScenario": summarize(scored),
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Scored {len(scored)} cases for {report['modelId']} in {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    prepare_parser = subparsers.add_parser("prepare")
    prepare_parser.add_argument("output", type=Path)
    prepare_parser.add_argument("--natural-dates", action="store_true")
    prepare_parser.add_argument("--quality-regressions", action="store_true")
    score_parser = subparsers.add_parser("score")
    score_parser.add_argument("cases", type=Path)
    score_parser.add_argument("results", type=Path)
    score_parser.add_argument("output", type=Path)
    score_parser.add_argument("--baseline-validator", type=Path)
    arguments = parser.parse_args()
    if arguments.command == "prepare":
        prepare(
            arguments.output, natural_dates=arguments.natural_dates, quality_regressions=arguments.quality_regressions
        )
    else:
        score(
            arguments.cases, arguments.results, arguments.output, baseline_validator_path=arguments.baseline_validator
        )


if __name__ == "__main__":
    main()
