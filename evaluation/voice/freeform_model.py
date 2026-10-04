from __future__ import annotations

import argparse
import json
import math
import time
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.common import CONFIG_DIR, ROOT
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.score_candidate import FIELD_WIRE_IDS, WIRE_FIELD_IDS, score_fields

MODE = "freeform-development"
CORPUS = TEXT_OUTPUT_DIR / "freeformDevelopment.jsonl"
MANIFEST = AUDIO_OUTPUT_DIR / MODE / "manifest.json"
MODEL = ROOT / "ios/DoglyadNeuralModel/Resources/mlx-Qwen2.5-1.5B-Instruct-4bit"
SCHEMA_SOURCE = ROOT / "ios/DoglyadNeuralModel/Examination/DExaminationProposalGenerationConfig.swift"
STRICT_PROMPT = {
    "en": (
        "The schema lists possible fields, not required fields. Omit every field absent from the dictation; "
        "never supply a placeholder, default patient, guessed date, or inferred gender. "
        "For each proposal, copy the shortest exact contiguous evidence from the dictation, "
        "preserving capitalization and punctuation. The quote must directly support that field and value; "
        "a broad passage containing unrelated facts is not evidence. "
        "Copy complaints only from patient-reported symptoms. Copy ultrasound findings only into "
        "examinationDescription, preserving sides, measurements, units, and negations. "
        "When the speaker corrects a number, use the final number and retain the correction in evidence."
    ),
    "ru": (
        "Схема перечисляет возможные, а не обязательные поля. Пропускай все поля, которых нет в диктовке; "
        "не подставляй вымышленного пациента, дату, пол или значения по умолчанию. "
        "Для каждого поля копируй кратчайшую точную непрерывную цитату evidence из диктовки "
        "с сохранением регистра и пунктуации. Цитата должна прямо подтверждать именно это поле и значение; "
        "большой фрагмент с посторонними фактами не считается доказательством. "
        "Жалобы бери только из слов пациента, данные УЗИ — только в examinationDescription, "
        "сохраняй сторону, числа, единицы и отрицания. При самоисправлении используй последнее число "
        "и сохрани исправление в evidence."
    ),
}


def schema_text() -> str:
    source = SCHEMA_SOURCE.read_text(encoding="utf-8")
    return source.split('static let responseJSONSchema: String = #"""', 1)[1].split('"""#', 1)[0]


def prepare_inputs(per_locale: int) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if per_locale < 1:
        raise ValueError("per_locale must be positive")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest["freeformDevelopmentSha256"] != file_sha256(CORPUS):
        raise ValueError("Freeform audio and text hashes differ")
    entries = {entry["caseId"]: entry for entry in manifest["entries"]}
    cases = [json.loads(line) for line in CORPUS.read_text(encoding="utf-8").splitlines()]
    selected = []
    counts = {"en": 0, "ru": 0}
    for case in cases:
        locale = case["locale"]
        if counts[locale] < per_locale:
            entry = entries[case["id"]]
            if entry["status"] != "ok":
                raise ValueError(f"Audio is unavailable for {case['id']}")
            selected.append({**case, "inputText": entry["ttsText"]})
            counts[locale] += 1
    if counts != {"en": per_locale, "ru": per_locale}:
        raise ValueError("Insufficient freeform cases for balanced diagnostic")
    return selected, manifest


def score_output(case: dict[str, Any], response: str) -> dict[str, Any]:
    try:
        generated = json.loads(response)
        if not isinstance(generated, list):
            raise ValueError("Proposal response is not an array")
    except (ValueError, TypeError) as error:
        return {"status": "invalidJSON", "reason": str(error)}

    raw: dict[str, Any] = {}
    quoted: dict[str, Any] = {}
    accuracies: dict[str, str] = {}
    quote_rejected: list[str] = []
    invalid: list[str] = []
    for item in generated:
        if not isinstance(item, dict) or item.get("field_id") not in WIRE_FIELD_IDS:
            invalid.append(str(item))
            continue
        field = WIRE_FIELD_IDS[item["field_id"]]
        if field in raw:
            invalid.append(f"duplicate: {field}")
            continue
        if "value" not in item:
            invalid.append(f"missing value: {field}")
            continue
        value: Any = item["value"]
        if field in ("patientHeightCM", "patientWeightKG"):
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                invalid.append(f"non-numeric: {field}")
                continue
            value = float(value)
            if not math.isfinite(value) or value <= 0:
                invalid.append(f"invalid measurement: {field}")
                continue
        elif not isinstance(value, str):
            invalid.append(f"non-text: {field}")
            continue
        accuracy = item.get("accuracy")
        if accuracy not in ("full", "questionable"):
            invalid.append(f"invalid accuracy: {field}")
            continue
        raw[field] = value
        accuracies[field] = accuracy
        quote = item.get("evidence")
        if isinstance(quote, str) and quote and quote in case["inputText"]:
            quoted[field] = value
        else:
            quote_rejected.append(field)
    return {
        "status": "ok",
        "rawFields": raw,
        "quotedFields": quoted,
        "quoteRejected": quote_rejected,
        "invalidProposals": invalid,
        "rawScore": score_fields(
            case["expectedFields"],
            {"fields": raw, "warnings": {}, "accuracies": accuracies},
            locale=case["locale"],
            normalize_description=True,
        ),
        "quotedScore": score_fields(
            case["expectedFields"],
            {"fields": quoted, "warnings": {}, "accuracies": accuracies},
            locale=case["locale"],
            normalize_description=True,
        ),
    }


def run(per_locale: int, output: Path, *, strict_prompt: bool = False) -> dict[str, Any]:
    # This Mac run uses the same weights and backend prompt, but has no Swift
    # constrained decoder or iOS proposal validator. It is a development
    # diagnostic, never a release metric for the product path.
    from mlx_lm import generate, load
    from mlx_lm.sample_utils import make_sampler

    cases, _ = prepare_inputs(per_locale)
    prompts = {
        locale: json.loads((CONFIG_DIR / locale / "l10n.json").read_text(encoding="utf-8"))[
            "examinationDictationProposalPrompt"
        ]
        for locale in ("en", "ru")
    }
    model, tokenizer = load(str(MODEL))[:2]
    rows: list[dict[str, Any]] = []
    report: dict[str, Any] = {
        "schemaVersion": 1,
        "route": "macMLXUnconstrainedDiagnostic",
        "promptVariant": "strict" if strict_prompt else "backendCurrent",
        "corpusSha256": file_sha256(CORPUS),
        "audioManifestSha256": file_sha256(MANIFEST),
        "modelConfigSha256": file_sha256(MODEL / "config.json"),
        "schemaSourceSha256": file_sha256(SCHEMA_SOURCE),
        "promptSha256": {locale: file_sha256(CONFIG_DIR / locale / "l10n.json") for locale in ("en", "ru")},
        "scriptSource": "ttsText",
        "cases": rows,
    }
    schema = schema_text()
    for case in cases:
        locale = case["locale"]
        user = (
            f"<examinationTypeId>{case['examinationTypeId']}</examinationTypeId>\n"
            f"<locale>{'ru-RU' if locale == 'ru' else 'en-US'}</locale>\n"
            f"<allowedFields>{', '.join(FIELD_WIRE_IDS.values())}</allowedFields>\n"
            f"<dictation>\n{case['inputText']}\n</dictation>"
        )
        chat = tokenizer.apply_chat_template(
            [
                {
                    "role": "system",
                    "content": prompts[locale]
                    + ("\n" + STRICT_PROMPT[locale] if strict_prompt else "")
                    + "\nReturn JSON matching this schema:\n"
                    + schema,
                },
                {"role": "user", "content": user},
            ],
            tokenize=True,
            add_generation_prompt=True,
        )
        started = time.monotonic()
        response = generate(model, tokenizer, prompt=chat, max_tokens=2048, sampler=make_sampler(temp=0.0))
        scored = score_output(case, response)
        rows.append(
            {
                "caseId": case["id"],
                "locale": locale,
                "scenario": case["scenario"],
                "elapsedSeconds": time.monotonic() - started,
                "response": response,
                **scored,
            }
        )
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"{case['id']}: {scored['status']}", flush=True)
    report["byLocale"] = {
        locale: {
            "cases": len(subset),
            "validJSON": sum(row["status"] == "ok" for row in subset),
            "rawExactForms": sum(row["status"] == "ok" and row["rawScore"]["equivalentExactCase"] for row in subset),
            "quoteAcceptedExactForms": sum(
                row["status"] == "ok" and row["quotedScore"]["equivalentExactCase"] for row in subset
            ),
            "quoteRejectedFields": sum(len(row.get("quoteRejected", [])) for row in subset),
        }
        for locale in ("en", "ru")
        if (subset := [row for row in rows if row["locale"] == locale])
    }
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Mac-only diagnostic of freeform proposal parsing")
    parser.add_argument("--per-locale", type=int, default=4)
    parser.add_argument("--strict-prompt", action="store_true")
    parser.add_argument("--output", type=Path, default=AUDIO_OUTPUT_DIR / MODE / "mac-model-gold-diagnostic.json")
    args = parser.parse_args()
    report = run(args.per_locale, args.output, strict_prompt=args.strict_prompt)
    print(json.dumps(report["byLocale"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
