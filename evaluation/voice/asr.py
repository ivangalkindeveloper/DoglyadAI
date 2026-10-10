from __future__ import annotations

import argparse
import json
import subprocess
import unicodedata
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.common import CONFIG_DIR, ROOT, load_catalog
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256

ASR_SOURCE = ROOT / "evaluation/voice/AudioASR/main.swift"
CORRECTOR_SOURCE = ROOT / "ios/DoglyadSpeech/Audio/DSpeechLexiconCorrector.swift"
LEXICON_LOCALIZATION_SOURCE = ROOT / "ios/DoglyadSpeech/Audio/DSpeechLexiconLocalization.swift"
CLASSIC_SOURCE = ROOT / "ios/DoglyadSpeech/SFSpeechRecognizer/DSpeechFileRecognizerSFSpeechRecognizer.swift"
FILE_RESULT_SOURCE = ROOT / "ios/DoglyadSpeech/Controller/DSpeechFileTranscription.swift"
FILE_ERROR_SOURCE = ROOT / "ios/DoglyadSpeech/Controller/DSpeechFileTranscriberError.swift"
CONFIDENCE_SPAN_SOURCE = ROOT / "ios/DoglyadSpeech/Span/DSpeechConfidenceSpan.swift"
FORM_LABEL_HINTS = {
    "en": [
        "examination number",
        "patient",
        "gender",
        "date of birth",
        "height",
        "weight",
        "complaints",
        "examination description",
    ],
    "ru": [
        "номер исследования",
        "пациент",
        "пол",
        "дата рождения",
        "рост",
        "вес",
        "жалобы",
        "описание исследования",
    ],
}


def words(text: str) -> list[str]:
    normalized = "".join(" " if unicodedata.category(char).startswith("P") else char for char in text.casefold())
    return normalized.split()


def word_error_rate(reference: str, actual: str) -> float:
    expected = words(reference)
    received = words(actual)
    if not expected:
        return 0.0 if not received else 1.0
    previous = list(range(len(received) + 1))
    for index, token in enumerate(expected, start=1):
        current = [index]
        for other_index, other in enumerate(received, start=1):
            current.append(
                min(current[-1] + 1, previous[other_index] + 1, previous[other_index - 1] + (token != other))
            )
        previous = current
    return previous[-1] / len(expected)


def run_asr(
    mode: str = "quick",
    *,
    limit: int | None = None,
    variant: str | None = None,
    form_label_hints: bool = False,
) -> dict[str, Any]:
    from evaluation.voice.spoken_wer import spoken_normalized_wer

    if variant not in (None, "clean", "noisy") or (mode == "quick" and variant == "noisy"):
        raise ValueError("Unsupported audio variant")
    directory = AUDIO_OUTPUT_DIR / mode if limit is None else AUDIO_OUTPUT_DIR / f"{mode}-smoke-{limit}"
    audio_manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
    if audio_manifest["mode"] != mode:
        raise ValueError("Audio manifest mode does not match requested mode")
    if audio_manifest["regressionSha256"] != file_sha256(TEXT_OUTPUT_DIR / "regression.jsonl"):
        raise ValueError("Audio and text regression sets differ; regenerate audio")
    split = audio_manifest.get("split", "regression")
    if split not in ("regression", "control", "voiceBlind", "freeformDevelopment"):
        raise ValueError("Unsupported audio corpus split")
    if split == "control" and audio_manifest.get("controlSha256") != file_sha256(TEXT_OUTPUT_DIR / "control.jsonl"):
        raise ValueError("Audio and control cases differ")
    if split == "voiceBlind" and audio_manifest.get("voiceBlindSha256") != file_sha256(
        TEXT_OUTPUT_DIR / "voiceBlind.jsonl"
    ):
        raise ValueError("Audio and blind cases differ")
    if split == "freeformDevelopment" and audio_manifest.get("freeformDevelopmentSha256") != file_sha256(
        TEXT_OUTPUT_DIR / "freeformDevelopment.jsonl"
    ):
        raise ValueError("Audio and freeform development cases differ")
    cases = {
        case["id"]: case
        for case in (
            json.loads(line) for line in (TEXT_OUTPUT_DIR / f"{split}.jsonl").read_text(encoding="utf-8").splitlines()
        )
    }
    _, terms = load_catalog()
    entries = audio_manifest["entries"]
    if limit is not None and len(entries) != limit:
        raise ValueError("Smoke audio manifest does not contain the requested number of cases")
    variants = (variant,) if variant else (("clean",) if mode == "quick" else ("clean", "noisy"))
    variant_label = variant or ("clean" if mode == "quick" else "both")
    suffix = f"form-label-hints-{variant_label}" if form_label_hints else variant or ""
    jobs: list[dict[str, Any]] = []
    job_cases: dict[str, tuple[dict[str, Any], str, str]] = {}
    for entry in entries:
        if entry["status"] != "ok":
            continue
        for variant in variants:
            audio = entry[variant]
            audio_path = ROOT / audio["path"]
            if file_sha256(audio_path) != audio["sha256"]:
                raise ValueError(f"Audio file differs from manifest: {audio_path}")
            job_id = entry["caseId"] if mode == "quick" else f"{entry['caseId']}::{variant}"
            jobs.append(
                {
                    "id": job_id,
                    "locale": entry["locale"],
                    "lexiconLocalization": json.loads(
                        (CONFIG_DIR / entry["locale"] / "l10n_voice_parsing.json").read_text(encoding="utf-8")
                    )["speech"],
                    "audioPath": str(audio_path),
                    "contextualStrings": terms[entry["locale"]][entry["examinationTypeId"]]
                    + (FORM_LABEL_HINTS[entry["locale"]] if form_label_hints else []),
                    "correctionStrings": terms[entry["locale"]][entry["examinationTypeId"]],
                    "isFarField": mode
                    in (
                        "extended-v2",
                        "voice-holdout",
                        "phrase-holdout",
                        "voice-blind-v3",
                        "guided-format",
                        "reordered-format",
                        "freeform-development",
                    ),
                }
            )
            case = cases[entry["caseId"]]
            job_cases[job_id] = (case, variant, entry.get("werReference", case["spokenText"]))
    jobs_path = directory / (f"asr-{suffix}-jobs.json" if suffix else "asr-jobs.json")
    results_path = directory / (f"asr-{suffix}-results.jsonl" if suffix else "asr-results.jsonl")
    jobs_path.write_text(json.dumps(jobs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    executable = AUDIO_OUTPUT_DIR / "voice-audio-asr"
    subprocess.run(
        [
            "swiftc",
            "-O",
            "-parse-as-library",
            "-module-cache-path",
            str(AUDIO_OUTPUT_DIR / "swift-module-cache"),
            str(ASR_SOURCE),
            str(CORRECTOR_SOURCE),
            str(LEXICON_LOCALIZATION_SOURCE),
            str(CLASSIC_SOURCE),
            str(FILE_RESULT_SOURCE),
            str(FILE_ERROR_SOURCE),
            str(CONFIDENCE_SPAN_SOURCE),
            "-o",
            str(executable),
        ],
        check=True,
    )
    subprocess.run([str(executable), str(jobs_path), str(results_path)], check=True, timeout=max(120, len(jobs) * 45))
    results = [json.loads(line) for line in results_path.read_text(encoding="utf-8").splitlines()]
    if [result["id"] for result in results] != [job["id"] for job in jobs]:
        raise ValueError("ASR results do not match requested jobs")

    scored = []
    for result in results:
        case, variant, reference = job_cases[result["id"]]
        item = {
            "caseId": case["id"],
            "locale": case["locale"],
            "variant": variant,
            **{key: value for key, value in result.items() if key != "id"},
        }
        if result["status"] == "ok":
            if mode in (
                "extended-v2",
                "voice-holdout",
                "phrase-holdout",
                "voice-blind-v3",
                "guided-format",
                "reordered-format",
                "freeform-development",
            ):
                item["rawWER"] = spoken_normalized_wer(reference, result["rawText"], case["locale"])
                item["correctedWER"] = spoken_normalized_wer(reference, result["correctedText"], case["locale"])
            else:
                item["rawWER"] = word_error_rate(reference, result["rawText"])
                item["correctedWER"] = word_error_rate(reference, result["correctedText"])
        scored.append(item)
    for entry in entries:
        if entry["status"] != "ok":
            for variant in variants:
                scored.append(
                    {
                        "caseId": entry["caseId"],
                        "locale": entry["locale"],
                        "variant": variant,
                        "status": "skipped",
                        "reason": "Audio unavailable",
                    }
                )
    successful = [item for item in scored if item["status"] == "ok"]
    report = {
        "schemaVersion": 1,
        "platform": "macOS",
        "recognizer": "DictationTranscriber with examination vocabulary"
        + (" and form labels" if form_label_hints else "")
        + " and existing DSpeechLexiconCorrector",
        "isIOSBaseline": False,
        "audioMode": mode,
        "audioVariant": variants[0] if len(variants) == 1 else None,
        "formLabelHints": FORM_LABEL_HINTS if form_label_hints else None,
        "requestedAudioFiles": len(entries) * len(variants),
        "recognizedAudioFiles": len(successful),
        "skippedAudioFiles": sum(item["status"] == "skipped" for item in scored),
        "failedAudioFiles": sum(item["status"] == "failed" for item in scored),
        "meanRawWER": sum(item["rawWER"] for item in successful) / len(successful) if successful else None,
        "meanCorrectedWER": sum(item["correctedWER"] for item in successful) / len(successful) if successful else None,
        "audioManifestSha256": file_sha256(directory / "manifest.json"),
        "asrSourceSha256": file_sha256(ASR_SOURCE),
        "asrOrchestratorSourceSha256": file_sha256(ROOT / "evaluation/voice/asr.py"),
        "correctorSourceSha256": file_sha256(CORRECTOR_SOURCE),
        "lexiconLocalizationSourceSha256": file_sha256(LEXICON_LOCALIZATION_SOURCE),
        "voiceLocalizationSha256": {
            locale: file_sha256(CONFIG_DIR / locale / "l10n_voice_parsing.json") for locale in ("en", "ru")
        },
        "contextualStringsSha256": {
            locale: file_sha256(CONFIG_DIR / locale / "l10n_ultrasound_examination_contextual_strings.json")
            for locale in ("en", "ru")
        },
        "results": scored,
    }
    report_path = directory / (f"asr-{suffix}-report.json" if suffix else "asr-report.json")
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Run macOS DictationTranscriber on synthetic audio")
    parser.add_argument(
        "--mode",
        choices=(
            "quick",
            "extended",
            "extended-v2",
            "voice-holdout",
            "phrase-holdout",
            "voice-blind-v3",
            "guided-format",
            "reordered-format",
            "freeform-development",
        ),
        default="quick",
    )
    parser.add_argument("--limit", type=int)
    parser.add_argument("--variant", choices=("clean", "noisy"))
    parser.add_argument("--form-label-hints", action="store_true")
    args = parser.parse_args()
    report = run_asr(
        args.mode,
        limit=args.limit,
        variant=args.variant,
        form_label_hints=args.form_label_hints,
    )
    print(
        f"Recognized {report['recognizedAudioFiles']}/{report['requestedAudioFiles']}; "
        f"skipped {report['skippedAudioFiles']}; failed {report['failedAudioFiles']}"
    )
    directory = (
        AUDIO_OUTPUT_DIR / args.mode if args.limit is None else AUDIO_OUTPUT_DIR / f"{args.mode}-smoke-{args.limit}"
    )
    variant_label = args.variant or ("clean" if args.mode == "quick" else "both")
    suffix = f"form-label-hints-{variant_label}" if args.form_label_hints else args.variant or ""
    print(f"Report: {directory / (f'asr-{suffix}-report.json' if suffix else 'asr-report.json')}")
    if report["recognizedAudioFiles"] != report["requestedAudioFiles"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
