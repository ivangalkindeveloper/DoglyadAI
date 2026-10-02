from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import time
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.common import CONFIG_DIR
from evaluation.voice.freeform_model import CORPUS, MANIFEST, MODEL, prepare_inputs, schema_text, score_output
from evaluation.voice.generate import file_sha256
from evaluation.voice.score_candidate import FIELDS

MODE = "freeform-development"
HARNESS = Path(__file__).parent / "MacGuidedHarness/.build/release/voice-guided"
NULLABLE_PROMPTS = {
    "en": (
        "Extract facts from a physician's dictation into the supplied JSON schema. "
        "Each key represents one possible form field. Use null if that field was not explicitly spoken; "
        "never invent a patient, date, sex, measurement, complaint, or finding. "
        "For a present field, value is the normalized field value and sourceQuote is a short, "
        "exact contiguous substring copied from <dictation>, including its original capitalization. "
        "Do not cite a sentence that does not directly support that field. "
        "Keep leading zeros in examinationNumber. Use male or female only if explicit. "
        "Convert a complete birth date to YYYY-MM-DD. Height is in centimeters and weight in kilograms "
        "only when the unit is clear. Keep symptoms in patientComplaints and ultrasound observations in "
        "examinationDescription. Preserve side, measurement, unit and negation; if a number is explicitly "
        "corrected, use the final number. Do not translate the dictated text."
    ),
    "ru": (
        "Извлеки факты из диктовки врача по заданной JSON-схеме. Каждый ключ — возможное поле формы. "
        "Если поле не произнесено явно, верни null; не выдумывай пациента, дату, пол, измерение, жалобу "
        "или находку. Для названного поля value — нормализованное значение, sourceQuote — короткая точная "
        "непрерывная цитата из <dictation> с исходным регистром. Цитата должна подтверждать именно это поле. "
        "Сохраняй ведущие нули номера исследования. Пол male/female указывай только при явном упоминании. "
        "Полную дату рождения приводи к YYYY-MM-DD. Рост в сантиметрах и вес в килограммах указывай "
        "только при понятной единице. Жалобы отделяй от наблюдений УЗИ. В описании сохраняй сторону, "
        "число, единицу и отрицание; при явном исправлении используй последнее число. Не переводи текст."
    ),
}


def nullable_schema() -> str:
    item = {
        "type": "object",
        "properties": {"value": {"type": "string", "minLength": 1}, "sourceQuote": {"type": "string", "minLength": 1}},
        "required": ["value", "sourceQuote"],
        "additionalProperties": False,
    }
    schema = {
        "type": "object",
        "properties": {field: {"anyOf": [item, {"type": "null"}]} for field in FIELDS},
        "required": list(FIELDS),
        "additionalProperties": False,
    }
    return json.dumps(schema, ensure_ascii=False, separators=(",", ":"))


def proposals_only_schema() -> str:
    schema = json.loads(schema_text())
    del schema["properties"]["unmappedFindings"]
    schema["required"].remove("unmappedFindings")
    return json.dumps(schema, ensure_ascii=False, separators=(",", ":"))


def normalize_nullable_response(output: str) -> str:
    parsed = json.loads(output)
    if not isinstance(parsed, dict) or set(parsed) != set(FIELDS):
        raise ValueError("Nullable response has missing or extra fields")
    proposals = []
    for field in FIELDS:
        item = parsed[field]
        if item is None:
            continue
        if (
            not isinstance(item, dict)
            or not isinstance(item.get("value"), str)
            or not isinstance(item.get("sourceQuote"), str)
        ):
            raise ValueError(f"Invalid nullable field: {field}")
        proposals.append({"fieldId": field, "value": item["value"], "sourceQuote": item["sourceQuote"]})
    return json.dumps({"proposals": proposals, "unmappedFindings": []}, ensure_ascii=False)


def normalize_proposals_only_response(output: str) -> str:
    parsed = json.loads(output)
    if not isinstance(parsed, dict) or set(parsed) != {"proposals"}:
        raise ValueError("Proposals-only response has missing or extra fields")
    return json.dumps({"proposals": parsed["proposals"], "unmappedFindings": []}, ensure_ascii=False)


def asr_inputs(report_path: Path, *, cases: list[dict[str, Any]]) -> dict[str, str]:
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if report["audioMode"] != MODE or report["audioManifestSha256"] != file_sha256(MANIFEST):
        raise ValueError("ASR report does not match the freeform audio manifest")
    by_id = {row["caseId"]: row for row in report["results"]}
    if len(by_id) != len(report["results"]):
        raise ValueError("Duplicate ASR case IDs")
    result = {}
    for case in cases:
        row = by_id[case["id"]]
        if row["status"] != "ok" or row["locale"] != case["locale"]:
            raise ValueError(f"ASR result unavailable or locale mismatch: {case['id']}")
        result[case["id"]] = row["correctedText"]
    return result


def run(
    per_locale: int,
    output: Path,
    asr_report: Path | None = None,
    *,
    nullable_fields: bool = False,
    proposals_only: bool = False,
    model_path: Path = MODEL,
    max_tokens: int = 2048,
    case_ids: list[str] | None = None,
) -> dict[str, Any]:
    if max_tokens < 1:
        raise ValueError("max_tokens must be positive")
    if nullable_fields and proposals_only:
        raise ValueError("Choose one schema variant")
    cases, _ = prepare_inputs(62 if case_ids else per_locale)
    if case_ids:
        selected = {case["id"] for case in cases}
        if set(case_ids) - selected:
            raise ValueError(f"Unknown case IDs: {set(case_ids) - selected}")
        cases = [case for case in cases if case["id"] in set(case_ids)]
    transcripts = asr_inputs(asr_report, cases=cases) if asr_report is not None else {}
    prompts = {
        locale: json.loads((CONFIG_DIR / locale / "l10n.json").read_text(encoding="utf-8"))[
            "examinationDictationProposalPrompt"
        ]
        for locale in ("en", "ru")
    }
    if not HARNESS.is_file():
        raise FileNotFoundError(f"Build Mac guided harness first: {HARNESS}")
    schema = nullable_schema() if nullable_fields else proposals_only_schema() if proposals_only else schema_text()
    system_prompts = NULLABLE_PROMPTS if nullable_fields else prompts
    if proposals_only:
        system_prompts = {
            "en": prompts["en"].replace(
                "Keep unsupported relevant clinical text in unmappedFindings rather than forcing it into a field.",
                "Omit unsupported clinical text rather than forcing it into a field.",
            ),
            "ru": prompts["ru"].replace(
                "Клинический текст, который не относится к допустимым полям, помещай в unmappedFindings, а не в неподходящее поле.",
                "Клинический текст, который не относится к допустимым полям, не подставляй в поле.",
            ),
        }
    rows: list[dict[str, Any]] = []
    report: dict[str, Any] = {
        "schemaVersion": 1,
        "route": "macSwiftGuidedGeneration",
        "schemaVariant": "nullableFields"
        if nullable_fields
        else "proposalsOnly"
        if proposals_only
        else "proposalArray",
        "maxTokens": max_tokens,
        "inputSource": "asrReport" if asr_report else "ttsScript",
        "asrReportSha256": file_sha256(asr_report) if asr_report else None,
        "corpusSha256": file_sha256(CORPUS),
        "audioManifestSha256": file_sha256(MANIFEST),
        "modelPath": str(model_path),
        "modelConfigSha256": file_sha256(model_path / "config.json"),
        "harnessSha256": file_sha256(HARNESS),
        "promptSha256": {locale: file_sha256(CONFIG_DIR / locale / "l10n.json") for locale in ("en", "ru")},
        "systemPromptSha256": {
            locale: hashlib.sha256(system_prompts[locale].encode("utf-8")).hexdigest() for locale in ("en", "ru")
        },
        "schemaSha256": hashlib.sha256(schema.encode("utf-8")).hexdigest(),
        "cases": rows,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with (output.parent / f"{output.stem}.log").open("w", encoding="utf-8") as log:
        with subprocess.Popen(
            [str(HARNESS), str(model_path)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=log,
            text=True,
            bufsize=1,
        ) as process:
            if process.stdin is None or process.stdout is None:
                raise RuntimeError("Could not communicate with Mac guided harness")
            for case in cases:
                locale = case["locale"]
                input_text = transcripts.get(case["id"], case["inputText"])
                user_prompt = (
                    f"<examinationTypeId>{case['examinationTypeId']}</examinationTypeId>\n"
                    f"<locale>{'ru-RU' if locale == 'ru' else 'en-US'}</locale>\n"
                    + ("" if nullable_fields else f"<allowedFields>{', '.join(FIELDS)}</allowedFields>\n")
                    + f"<dictation>\n{input_text}\n</dictation>"
                )
                request = {
                    "id": case["id"],
                    "systemPrompt": system_prompts[locale],
                    "userPrompt": user_prompt,
                    "schema": schema,
                    "maxTokens": max_tokens,
                }
                started = time.monotonic()
                process.stdin.write(json.dumps(request, ensure_ascii=False) + "\n")
                process.stdin.flush()
                for line in process.stdout:
                    if line.startswith("VOICE_GUIDED:"):
                        answer = json.loads(line[len("VOICE_GUIDED:") :])
                        break
                else:
                    raise RuntimeError(f"Mac guided harness stopped while parsing {case['id']}")
                if answer["id"] != case["id"]:
                    raise ValueError("Mac guided harness returned another case")
                if answer.get("error"):
                    scored: dict[str, Any] = {"status": "failed", "reason": answer["error"]}
                    normalized = None
                else:
                    try:
                        if nullable_fields:
                            normalized = normalize_nullable_response(answer["output"])
                        elif proposals_only:
                            normalized = normalize_proposals_only_response(answer["output"])
                        else:
                            normalized = answer["output"]
                        scored = score_output({**case, "inputText": input_text}, normalized)
                    except (ValueError, KeyError, TypeError) as error:
                        normalized = None
                        scored = {"status": "invalidJSON", "reason": str(error)}
                rows.append(
                    {
                        "caseId": case["id"],
                        "locale": locale,
                        "scenario": case["scenario"],
                        "inputText": input_text,
                        "elapsedSeconds": time.monotonic() - started,
                        "modelResponse": answer.get("output"),
                        "response": normalized,
                        **scored,
                    }
                )
                output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
                print(f"{case['id']}: {scored['status']}", flush=True)
            process.stdin.close()
            if process.wait(timeout=30) != 0:
                raise RuntimeError(f"Mac guided harness failed; see {output.parent / f'{output.stem}.log'}")
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
    parser = argparse.ArgumentParser(description="Run iOS-equivalent guided Qwen inference on Mac")
    parser.add_argument("--per-locale", type=int, default=4)
    parser.add_argument("--asr-report", type=Path)
    parser.add_argument("--nullable-fields", action="store_true")
    parser.add_argument("--proposals-only", action="store_true")
    parser.add_argument("--model-path", type=Path, default=MODEL)
    parser.add_argument("--max-tokens", type=int, default=2048)
    parser.add_argument("--case-id", action="append")
    parser.add_argument("--output", type=Path, default=AUDIO_OUTPUT_DIR / MODE / "mac-guided-gold.json")
    args = parser.parse_args()
    report = run(
        args.per_locale,
        args.output,
        args.asr_report,
        nullable_fields=args.nullable_fields,
        proposals_only=args.proposals_only,
        model_path=args.model_path,
        max_tokens=args.max_tokens,
        case_ids=args.case_id,
    )
    print(json.dumps(report["byLocale"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
