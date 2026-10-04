from __future__ import annotations

import argparse
import json
import os
import shutil
import time
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.common import CONFIG_DIR, ROOT, load_catalog
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256

FIXTURE_DIR = ROOT / "ios/DoglyadTests/VoiceFixtures"
SOURCE_FILES = (
    ROOT / "ios/DoglyadSpeech/DictationCompletion.swift",
    ROOT / "ios/DoglyadSpeech/DictationEngine.swift",
    ROOT / "ios/DoglyadSpeech/DSpeechConfidenceSpan.swift",
    ROOT / "ios/DoglyadSpeech/Controller/DSpeechControllerAnalyzer.swift",
    ROOT / "ios/DoglyadSpeech/Controller/DSpeechAnalyzerConfiguration.swift",
    ROOT / "ios/DoglyadSpeech/Controller/DSpeechControllerSFSpeechRecognizer.swift",
    ROOT / "ios/DoglyadSpeech/Controller/DSpeechFileTranscriber.swift",
    ROOT / "ios/DoglyadSpeech/Controller/DSpeechFileRecognizerSFSpeechRecognizer.swift",
    ROOT / "ios/DoglyadSpeech/Audio/DSpeechLexiconCorrector.swift",
    ROOT / "ios/DoglyadTests/VoiceBaselineTests.swift",
    ROOT / "ios/DoglyadTests/VoiceCandidateTests.swift",
    ROOT / "ios/DoglyadTests/DictationLabeledFormParserTests.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DExaminationNeuralModelFactory.swift",
    ROOT / "ios/DoglyadNeuralModel/DNeuralDevice.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/Model/DExaminationNeuralModelMLX.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/Model/DExaminationNeuralModelFoundationModels.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DExaminationProposalGenerationConfig.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationProposal.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationProposalReconciler.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationProposalSource.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationLabeledFormParser.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationExplicitFactsExtractor.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationIdentifierCue.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationFollowingFieldCue.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationSectionCue.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationObservationCue.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationDescriptionNormalizer.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationNumericCorrection.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationNaturalLanguageParser.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationSpokenBirthDate.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/VoiceGender.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/SpokenDigitSequence.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/SpokenCardinal.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationTextFacts.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationUnit.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/DictationProposalValidator.swift",
    ROOT / "ios/DoglyadNeuralModel/Examination/VoiceFieldValue.swift",
    ROOT / "ios/Doglyad/Application/Module/Scan/Scan/ScanViewModel.swift",
    ROOT / "ios/Doglyad/Application/Module/Scan/ScanSpeech/ScanSpeechViewModel.swift",
    ROOT / "ios/Doglyad/Application/Module/Scan/ScanSpeech/ScanSpeechReviewPolicy.swift",
    ROOT / "ios/Doglyad/Application/Module/Scan/ScanSpeech/ScanSpeechConfidencePolicy.swift",
    ROOT / "ios/Doglyad/Application/Module/Scan/Scan/ScanFormPatch.swift",
)


def prepare_fixtures(
    *,
    limit: int | None = None,
    locale: str | None = None,
    mode: str = "quick",
    variant: str = "clean",
    measure_gold: bool | None = None,
    text_only: bool = False,
    replay_macos_asr: bool = False,
    replay_asr_report: Path | None = None,
    apply_replay_lexicon: bool = False,
    all_regression_text: bool = False,
    max_tokens: int | None = None,
    destination: Path = FIXTURE_DIR,
) -> dict[str, Any]:
    if replay_macos_asr and replay_asr_report is not None:
        raise ValueError("Choose only one ASR replay source")
    if apply_replay_lexicon and replay_asr_report is None:
        raise ValueError("Lexicon replay requires an ASR report")
    if all_regression_text and (not text_only or replay_macos_asr or replay_asr_report is not None):
        raise ValueError("Full regression corpus requires original text-only input")
    if (replay_macos_asr or replay_asr_report is not None) and not text_only:
        raise ValueError("ASR replay requires text-only mode")
    if mode == "quick" and variant != "clean":
        raise ValueError("Quick corpus has only clean audio")
    if mode not in (
        "quick",
        "extended",
        "extended-v2",
        "voice-holdout",
        "phrase-holdout",
        "voice-blind-v3",
        "guided-format",
        "reordered-format",
        "freeform-development",
    ) or variant not in (
        "clean",
        "noisy",
    ):
        raise ValueError("Unsupported audio mode or variant")
    manifest_path = AUDIO_OUTPUT_DIR / mode / "manifest.json"
    audio_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    text_manifest = json.loads((TEXT_OUTPUT_DIR / "manifest.json").read_text(encoding="utf-8"))
    if audio_manifest["regressionSha256"] != text_manifest["regressionSha256"]:
        raise ValueError("Audio and text corpus hashes differ")
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
        raise ValueError("Audio and freeform cases differ")
    if all_regression_text and split != "regression":
        raise ValueError("Full regression corpus requires the regression split")
    asr_report_path = replay_asr_report or AUDIO_OUTPUT_DIR / mode / "asr-report.json"
    replay_results: dict[tuple[str, str], dict[str, Any]] = {}
    replay_recognizer: str | None = None
    if replay_macos_asr or replay_asr_report is not None:
        asr_report = json.loads(asr_report_path.read_text(encoding="utf-8"))
        if asr_report["audioManifestSha256"] != file_sha256(manifest_path):
            raise ValueError("ASR results use another audio manifest")
        if asr_report.get("audioVariant") not in (None, variant):
            raise ValueError("ASR report uses another audio variant")
        replay_recognizer = asr_report["recognizer"]
        replay_results = {(row["caseId"], row["variant"]): row for row in asr_report["results"]}
        if len(replay_results) != len(asr_report["results"]):
            raise ValueError("Duplicate macOS ASR results")

    cases = {
        case["id"]: case
        for case in (
            json.loads(line) for line in (TEXT_OUTPUT_DIR / f"{split}.jsonl").read_text(encoding="utf-8").splitlines()
        )
    }
    entries = (
        [{"caseId": case["id"], "locale": case["locale"], "status": "ok"} for case in cases.values()]
        if all_regression_text
        else audio_manifest["entries"]
    )
    if locale is not None:
        entries = [entry for entry in entries if entry["locale"] == locale]
    if limit is not None:
        if limit < 1:
            raise ValueError("Limit must be positive")
        entries = entries[:limit]
    _, terms = load_catalog()
    prompts = {
        locale: json.loads((CONFIG_DIR / locale / "l10n.json").read_text(encoding="utf-8"))[
            "examinationNeuralModelPrompt"
        ]
        for locale in ("en", "ru")
    }
    proposal_prompts = {
        locale: json.loads((CONFIG_DIR / locale / "l10n.json").read_text(encoding="utf-8"))[
            "examinationDictationProposalPrompt"
        ]
        for locale in ("en", "ru")
    }
    application = json.loads((CONFIG_DIR / "application.json").read_text(encoding="utf-8"))
    parameters = application["ultrasound"]["examinationNeuralModel"]

    destination.mkdir(parents=True, exist_ok=True)
    prepared = []
    for entry in entries:
        if entry["status"] != "ok":
            raise ValueError(f"Audio is unavailable for {entry['caseId']}")
        case = cases[entry["caseId"]]
        input_text = (
            entry["ttsText"]
            if mode
            in (
                "extended-v2",
                "voice-holdout",
                "phrase-holdout",
                "voice-blind-v3",
                "guided-format",
                "reordered-format",
                "freeform-development",
            )
            else case["spokenText"]
        )
        replay_result: dict[str, Any] | None = None
        if replay_recognizer is not None:
            result = replay_results.get((case["id"], variant))
            if result is None or result["status"] != "ok" or not result.get("correctedText"):
                raise ValueError(f"No completed ASR transcript for {case['id']} ({variant})")
            if result["locale"] != case["locale"]:
                raise ValueError(f"ASR transcript locale differs from {case['id']}")
            input_text = result["correctedText"]
            replay_result = result
        prepared_case = {
            "id": case["id"],
            "locale": case["locale"],
            "examinationTypeId": case["examinationTypeId"],
            "spokenText": input_text,
            "contextualStrings": terms[case["locale"]][case["examinationTypeId"]],
            "systemPrompt": prompts[case["locale"]],
            "proposalPrompt": proposal_prompts[case["locale"]],
        }
        if replay_result is not None:
            prepared_case["replayASR"] = {
                "rawText": replay_result.get("rawText", input_text),
                "confidenceSpans": replay_result.get("confidenceSpans", []),
                "applyLexicon": apply_replay_lexicon,
            }
        if not all_regression_text:
            source = ROOT / entry[variant]["path"]
            if file_sha256(source) != entry[variant]["sha256"]:
                raise ValueError(f"Audio hash mismatch for {entry['caseId']}")
            audio_name = f"{case['id']}-{variant}.wav"
            target = destination / audio_name
            if not text_only and (not target.exists() or file_sha256(target) != entry[variant]["sha256"]):
                shutil.copy2(source, target)
            prepared_case["audioFile"] = audio_name
            prepared_case["audioSha256"] = entry[variant]["sha256"]
        prepared.append(prepared_case)

    fixture = {
        "schemaVersion": 1,
        "split": split,
        "cases": prepared,
        "measureGold": (text_only or mode == "quick") if measure_gold is None else measure_gold,
        "generation": {
            "temperature": parameters["temperature"],
            "maxTokens": parameters["maxTokens"] if max_tokens is None else max_tokens,
            "maxContextTokens": parameters["maxContextTokens"],
        },
        "regressionSha256": text_manifest["regressionSha256"],
        "controlSha256": text_manifest["controlSha256"] if split == "control" else None,
        "voiceBlindSha256": audio_manifest.get("voiceBlindSha256") if split == "voiceBlind" else None,
        "freeformDevelopmentSha256": audio_manifest.get("freeformDevelopmentSha256")
        if split == "freeformDevelopment"
        else None,
        "audioManifestSha256": None if all_regression_text else file_sha256(manifest_path),
        "audioMode": mode,
        "audioVariant": variant,
        "promptSha256": {locale: file_sha256(CONFIG_DIR / locale / "l10n.json") for locale in ("en", "ru")},
        "contextualStringsSha256": {
            locale: file_sha256(CONFIG_DIR / locale / "l10n_ultrasound_examination_contextual_strings.json")
            for locale in ("en", "ru")
        },
        "applicationSha256": file_sha256(CONFIG_DIR / "application.json"),
        "sourceFilesSha256": {str(path.relative_to(ROOT)): file_sha256(path) for path in SOURCE_FILES},
        "inputSource": "macosASR" if replay_macos_asr else "asrReplay" if replay_recognizer else "originalText",
        "replayLexiconApplied": apply_replay_lexicon,
        "asrRecognizer": replay_recognizer,
        "asrReportSha256": file_sha256(asr_report_path) if replay_recognizer else None,
    }
    if text_only:
        fixture["textOnly"] = True
    fixture_path = destination / "cases.json"
    temporary = destination / "cases.json.tmp"
    previous_stamp = fixture_path.stat().st_mtime_ns if fixture_path.exists() else 0
    temporary.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, fixture_path)
    # Xcode can check either the source file or its containing folder when
    # copying resources. Advance both, even across back-to-back test runs.
    stamp = max(time.time_ns(), previous_stamp + 1_000_000_000, destination.stat().st_mtime_ns + 1_000_000_000)
    os.utime(fixture_path, ns=(stamp, stamp))
    os.utime(destination, ns=(stamp, stamp))
    return fixture


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare synthetic audio for the iOS test target")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--locale", choices=("en", "ru"))
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
    parser.add_argument("--variant", choices=("clean", "noisy"), default="clean")
    args = parser.parse_args()
    fixture = prepare_fixtures(limit=args.limit, locale=args.locale, mode=args.mode, variant=args.variant)
    print(f"Prepared {len(fixture['cases'])} iOS cases in {FIXTURE_DIR}")


if __name__ == "__main__":
    main()
