from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import time
import uuid
from pathlib import Path
from typing import Any

from evaluation.voice.common import ROOT
from evaluation.voice.prepare_ios import prepare_fixtures
from evaluation.voice.prepare_control_ios import prepare_adversarial_fixtures, prepare_control_fixtures
from evaluation.voice.prepare_holdout_ios import HOLDOUTS
from evaluation.voice.prepare_holdout_ios import prepare_holdout_fixtures
from evaluation.voice.score_ios import score_ios_report
from evaluation.voice.score_candidate import require_exact_gold_text, score_candidate_report

OUTPUT_ROOT = ROOT / "build/voice-eval"


def simulator_id(name: str) -> str:
    listing = subprocess.run(["xcrun", "simctl", "list", "-j", "devices"], capture_output=True, text=True, check=True)
    devices = json.loads(listing.stdout)["devices"]
    matching = [
        item["udid"] for group in devices.values() for item in group if item["name"] == name and item["isAvailable"]
    ]
    if len(matching) != 1:
        raise ValueError(f"Expected exactly one available simulator named {name}; found {len(matching)}")
    return matching[0]


def latest_report(device_id: str, after: float, report_name: str = "voice-baseline-ios.json") -> Path:
    directory = Path.home() / "Library/Developer/CoreSimulator/Devices" / device_id / "data/Containers/Data/Application"
    candidates = list(directory.glob(f"*/Documents/{report_name}"))
    fresh = [path for path in candidates if path.stat().st_mtime >= after]
    if not fresh:
        raise FileNotFoundError(f"No new iOS voice baseline report under {directory}")
    return max(fresh, key=lambda path: path.stat().st_mtime)


def copy_device_report(device_id: str, report_name: str, destination: Path) -> None:
    command = [
        "xcrun",
        "devicectl",
        "device",
        "copy",
        "from",
        "--device",
        device_id,
        "--source",
        f"Documents/{report_name}",
        "--domain-type",
        "appDataContainer",
        "--domain-identifier",
        "com.medical.doglyad.development",
        "--destination",
        str(destination),
    ]
    for attempt in range(3):
        destination.unlink(missing_ok=True)
        completed = subprocess.run(command, capture_output=True, text=True, check=False)
        if completed.returncode == 0 and destination.exists():
            return
        if attempt < 2:
            time.sleep(5)
    raise RuntimeError(f"Could not copy {report_name} from device: {completed.stderr.strip()}")


def run_ios(
    *,
    limit: int | None = None,
    locale: str | None = None,
    device: str = "iPhone 17",
    candidate: bool = False,
    mode: str = "quick",
    variant: str = "clean",
    control: bool = False,
    adversarial: bool = False,
    skip_gold: bool = False,
    text_only: bool = False,
    replay_macos_asr: bool = False,
    replay_asr_report: Path | None = None,
    apply_replay_lexicon: bool = False,
    all_regression_text: bool = False,
    holdout_v4: bool = False,
    holdout_v5: bool = False,
    holdout_v6: bool = False,
    holdout_v7: bool = False,
    holdout_v8: bool = False,
    max_tokens: int | None = None,
    physical_device_id: str | None = None,
    diagnostic_only: bool = False,
    confidence_only: bool = False,
    asr_only: bool = False,
    asr_engine_only: str | None = None,
    no_far_field_hint: bool = False,
    parse_strategy: str = "production",
    output_tag: str | None = None,
) -> dict[str, Any]:
    if output_tag is not None and re.fullmatch(r"[a-z0-9][a-z0-9-]*", output_tag) is None:
        raise ValueError("Output tag must contain only lowercase letters, digits, and hyphens")
    if control and adversarial:
        raise ValueError("Choose one text-only corpus")
    if control and (not candidate or limit is not None or locale is not None):
        raise ValueError("Control run requires a full candidate evaluation")
    if adversarial and (not candidate or limit is not None or locale is not None):
        raise ValueError("Adversarial run requires a full candidate evaluation")
    if skip_gold and (control or adversarial):
        raise ValueError("Text-only evaluations require gold-text parsing")
    if text_only and (not candidate or control or adversarial or skip_gold):
        raise ValueError("Regression text-only mode requires candidate gold-text parsing")
    if replay_macos_asr and replay_asr_report is not None:
        raise ValueError("Choose only one ASR replay source")
    if apply_replay_lexicon and replay_asr_report is None:
        raise ValueError("Lexicon replay requires an ASR report")
    if all_regression_text and (not candidate or not text_only or replay_macos_asr or replay_asr_report is not None):
        raise ValueError("Full regression corpus requires candidate original text-only input")
    if (replay_macos_asr or replay_asr_report is not None) and (
        not candidate or not text_only or control or adversarial
    ):
        raise ValueError("ASR replay requires candidate text-only regression mode")
    if max_tokens is not None and (not candidate or max_tokens <= 0):
        raise ValueError("A positive max-tokens override requires candidate mode")
    if diagnostic_only and (not candidate or not text_only):
        raise ValueError("Diagnostic-only mode requires candidate text-only mode")
    if confidence_only and (not candidate or text_only or control or adversarial):
        raise ValueError("Confidence-only mode requires candidate audio mode")
    if asr_only and (not candidate or text_only or control or adversarial):
        raise ValueError("ASR-only mode requires candidate audio mode")
    if asr_engine_only not in (None, "speechAnalyzer", "sfSpeechRecognizer") or (
        asr_engine_only is not None and (not asr_only or confidence_only)
    ):
        raise ValueError("An ASR engine filter requires ASR-only mode without confidence-only mode")
    if no_far_field_hint and (not asr_only or not confidence_only):
        raise ValueError("The far-field comparison requires confidence-only ASR mode")
    if parse_strategy not in {
        "production",
        "exactLabels",
        "explicitRules",
        "naturalLanguage",
        "foundationModels",
    }:
        raise ValueError(f"Unknown voice parse strategy: {parse_strategy}")
    if parse_strategy != "production" and (not candidate or not text_only):
        raise ValueError("Direct parse strategies require candidate text-only mode")
    if sum((holdout_v4, holdout_v5, holdout_v6, holdout_v7, holdout_v8)) > 1:
        raise ValueError("Choose one holdout version")
    holdout_version = (
        8 if holdout_v8 else 7 if holdout_v7 else 6 if holdout_v6 else 5 if holdout_v5 else 4 if holdout_v4 else None
    )
    if holdout_version is not None and (
        not candidate
        or not text_only
        or locale not in ("en", "ru")
        or limit is not None
        or control
        or adversarial
        or skip_gold
        or replay_macos_asr
        or replay_asr_report is not None
        or apply_replay_lexicon
        or all_regression_text
        or max_tokens is not None
        or confidence_only
        or asr_only
        or mode != "quick"
        or variant != "clean"
    ):
        raise ValueError("Holdout requires a complete locale-specific candidate text-only run")
    fixture = (
        prepare_holdout_fixtures(locale=locale, version=holdout_version)
        if holdout_version is not None
        else prepare_control_fixtures()
        if control
        else prepare_adversarial_fixtures()
        if adversarial
        else prepare_fixtures(
            limit=limit,
            locale=locale,
            mode=mode,
            variant=variant,
            measure_gold=False if skip_gold else None,
            text_only=text_only,
            replay_macos_asr=replay_macos_asr,
            replay_asr_report=replay_asr_report,
            apply_replay_lexicon=apply_replay_lexicon,
            all_regression_text=all_regression_text,
            max_tokens=max_tokens,
        )
    )
    prefix = "ios-candidate" if candidate else "ios"
    if physical_device_id is not None:
        prefix += "-device"
    if text_only:
        prefix += "-text"
    if replay_macos_asr:
        prefix += "-macos-asr-replay"
    if replay_asr_report is not None:
        prefix += f"-asr-replay-{replay_asr_report.parent.name}-{replay_asr_report.stem}"
    if apply_replay_lexicon:
        prefix += "-lexicon"
    if all_regression_text:
        prefix += "-all-regression"
    if max_tokens is not None:
        prefix += f"-tokens{max_tokens}"
    if diagnostic_only:
        prefix += "-diagnostic"
    if confidence_only:
        prefix += "-confidence-only"
    if asr_only:
        prefix += "-asr-only"
    if asr_engine_only is not None:
        prefix += f"-{asr_engine_only}-only"
    if no_far_field_hint:
        prefix += "-no-far-field-hint"
    if parse_strategy != "production":
        prefix += f"-{parse_strategy}"
    if holdout_version is not None:
        suffix = f"{prefix}-holdout-v{holdout_version}-{locale}"
    elif control:
        suffix = f"{prefix}-control"
    elif adversarial:
        suffix = f"{prefix}-adversarial"
    elif limit is None and locale is None:
        suffix = prefix if mode == "quick" else f"{prefix}-{mode}-{variant}"
    else:
        suffix = f"{prefix}-{mode}-{variant}-smoke-{locale or 'both'}-{limit or 'all'}"
    if output_tag is not None:
        suffix += f"-{output_tag}"
    output = OUTPUT_ROOT / suffix
    output.mkdir(parents=True, exist_ok=True)
    device_id = physical_device_id or simulator_id(device)
    started = time.time()
    run_id = uuid.uuid4().hex
    state_path = output / "run-state.json"
    state_path.write_text(
        json.dumps({"status": "running", "runId": run_id, "startedAtUnix": started}, indent=2) + "\n",
        encoding="utf-8",
    )
    command = [
        "xcodebuild",
        "-quiet",
        "test",
        "-project",
        "ios/Doglyad.xcodeproj",
        "-scheme",
        "Doglyad-Debug-Development",
        "-destination",
        f"platform={'iOS' if physical_device_id else 'iOS Simulator'},id={device_id}",
        "-parallel-testing-enabled",
        "NO",
        "-test-timeouts-enabled",
        "NO",
        "-only-testing:DoglyadTests/VoiceCandidateTests/testVoiceCandidate"
        if candidate
        else "-only-testing:DoglyadTests/VoiceBaselineTests/testVoiceBaseline",
    ]
    if physical_device_id is None:
        command.append("CODE_SIGNING_ALLOWED=NO")
    environment = os.environ.copy()
    environment["TEST_RUNNER_VOICE_CANDIDATE_RUN" if candidate else "TEST_RUNNER_VOICE_BASELINE_RUN"] = "1"
    if candidate:
        environment["TEST_RUNNER_VOICE_EXPECTED_AUDIO_MODE"] = HOLDOUTS[holdout_version][2] if holdout_version else mode
    if confidence_only:
        environment["TEST_RUNNER_VOICE_ASR_CONFIDENCE_ONLY"] = "1"
    if asr_only:
        environment["TEST_RUNNER_VOICE_ASR_ONLY"] = "1"
    if asr_engine_only is not None:
        environment["TEST_RUNNER_VOICE_ASR_ENGINE_ONLY"] = asr_engine_only
    if no_far_field_hint:
        environment["TEST_RUNNER_VOICE_ASR_NO_FAR_FIELD_HINT"] = "1"
    if parse_strategy != "production":
        environment["TEST_RUNNER_VOICE_PARSE_STRATEGY"] = parse_strategy
    environment["TEST_RUNNER_VOICE_REPORT_ID"] = run_id
    with (output / "xcodebuild.log").open("w", encoding="utf-8") as log:
        completed = subprocess.run(
            command, cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT, check=False
        )
    if completed.returncode != 0:
        raise RuntimeError(f"xcodebuild test failed with code {completed.returncode}; see {output / 'xcodebuild.log'}")
    report_name = f"voice-{'candidate' if candidate else 'baseline'}-ios-{run_id}.json"
    report_path = output / "results.json"
    if physical_device_id:
        copy_device_report(device_id, report_name, report_path)
    else:
        report_source = latest_report(device_id, started, report_name)
        shutil.copy2(report_source, report_path)
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if report.get("runId") != run_id:
        raise ValueError("iOS runner returned a report from another run")
    if report.get("fixtureRegressionSha256") != fixture.get("regressionSha256"):
        raise ValueError("iOS runner used a different regression corpus")
    if holdout_version is not None and report.get(f"fixtureHoldoutV{holdout_version}Sha256") != fixture.get(
        f"holdoutV{holdout_version}Sha256"
    ):
        raise ValueError("iOS runner used a different holdout corpus")
    if candidate:
        if report.get("asrNoFarFieldHint", False) != no_far_field_hint:
            raise ValueError("iOS runner used another acoustic hint")
        expected_strategy = parse_strategy
        if any(row.get("parseStrategy") != expected_strategy for row in report["results"]):
            raise ValueError("iOS runner used a different parse strategy")
        for report_key, fixture_key in (
            ("fixtureInputSource", "inputSource"),
            ("fixtureASRReportSha256", "asrReportSha256"),
            ("fixtureAudioManifestSha256", "audioManifestSha256"),
            ("fixtureReplayLexiconApplied", "replayLexiconApplied"),
        ):
            if report.get(report_key) != fixture.get(fixture_key):
                raise ValueError(f"iOS runner used stale fixture: {report_key}")
    if len(report["results"]) != len(fixture["cases"]):
        raise ValueError("iOS runner returned fewer cases than prepared")
    summary = score_candidate_report(report_path, output) if candidate else score_ios_report(report_path, output)
    (output / "runner.json").write_text(
        json.dumps(
            {
                "device": device if physical_device_id is None else "physical iPhone",
                "deviceId": device_id,
                "runId": run_id,
                "isPhysical": physical_device_id is not None,
                "confidenceOnly": confidence_only,
                "asrOnly": asr_only,
                "noFarFieldHint": no_far_field_hint,
                "textOnly": text_only,
                "inputSource": fixture.get("inputSource", "originalText"),
                "asrReportSha256": fixture.get("asrReportSha256"),
                "asrRecognizer": fixture.get("asrRecognizer"),
                "replayLexiconApplied": apply_replay_lexicon,
                "generationMaxTokens": fixture["generation"]["maxTokens"],
                "parseStrategy": parse_strategy,
                "xcodebuildExitCode": completed.returncode,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    state_path.write_text(
        json.dumps({"status": "complete", "runId": run_id, "startedAtUnix": started}, indent=2) + "\n",
        encoding="utf-8",
    )
    if (
        candidate
        and fixture.get("measureGold", True)
        and not diagnostic_only
        and not asr_only
        and holdout_version is None
    ):
        require_exact_gold_text(summary)
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the existing iOS voice path on synthetic WAV files")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--locale", choices=("en", "ru"))
    parser.add_argument("--device", default="iPhone 17")
    parser.add_argument("--physical-device-id")
    parser.add_argument("--output-tag")
    parser.add_argument("--candidate", action="store_true")
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
    parser.add_argument("--control", action="store_true")
    parser.add_argument("--adversarial", action="store_true")
    parser.add_argument("--skip-gold", action="store_true")
    parser.add_argument("--text-only", action="store_true")
    parser.add_argument("--replay-macos-asr", action="store_true")
    parser.add_argument("--replay-asr-report", type=Path)
    parser.add_argument("--apply-replay-lexicon", action="store_true")
    parser.add_argument("--all-regression-text", action="store_true")
    parser.add_argument("--holdout-v4", action="store_true")
    parser.add_argument("--holdout-v5", action="store_true")
    parser.add_argument("--holdout-v6", action="store_true")
    parser.add_argument("--holdout-v7", action="store_true")
    parser.add_argument("--holdout-v8", action="store_true")
    parser.add_argument("--max-tokens", type=int)
    parser.add_argument("--diagnostic-only", action="store_true")
    parser.add_argument("--confidence-only", action="store_true")
    parser.add_argument("--asr-only", action="store_true")
    parser.add_argument("--asr-engine-only", choices=("speechAnalyzer", "sfSpeechRecognizer"))
    parser.add_argument("--no-far-field-hint", action="store_true")
    parser.add_argument(
        "--parse-strategy",
        choices=("production", "exactLabels", "explicitRules", "naturalLanguage", "foundationModels"),
        default="production",
    )
    args = parser.parse_args()
    summary = run_ios(
        limit=args.limit,
        locale=args.locale,
        device=args.device,
        candidate=args.candidate,
        mode=args.mode,
        variant=args.variant,
        control=args.control,
        adversarial=args.adversarial,
        skip_gold=args.skip_gold,
        text_only=args.text_only,
        replay_macos_asr=args.replay_macos_asr,
        replay_asr_report=args.replay_asr_report,
        apply_replay_lexicon=args.apply_replay_lexicon,
        all_regression_text=args.all_regression_text,
        holdout_v4=args.holdout_v4,
        holdout_v5=args.holdout_v5,
        holdout_v6=args.holdout_v6,
        holdout_v7=args.holdout_v7,
        holdout_v8=args.holdout_v8,
        max_tokens=args.max_tokens,
        physical_device_id=args.physical_device_id,
        diagnostic_only=args.diagnostic_only,
        confidence_only=args.confidence_only,
        asr_only=args.asr_only,
        asr_engine_only=args.asr_engine_only,
        no_far_field_hint=args.no_far_field_hint,
        parse_strategy=args.parse_strategy,
        output_tag=args.output_tag,
    )
    print(f"iOS cases: {summary['requestedCases']}")
    for locale, metrics in summary["byLocale"].items():
        if args.candidate:
            text_label = "ASR replay parse" if args.replay_macos_asr or args.replay_asr_report else "gold-text parse"
            print(
                f"{locale}: {text_label} {metrics['goldTextScoredCases']}/{metrics['cases']}; "
                f"Analyzer parse {metrics['speechAnalyzer']['scoredCases']}/{metrics['cases']}; "
                f"classic parse {metrics['sfSpeechRecognizer']['scoredCases']}/{metrics['cases']}"
            )
        else:
            print(
                f"{locale}: ASR {metrics['asrStatuses'].get('ok', 0)}/{metrics['cases']}; "
                f"gold-text parse {metrics['goldTextScoredCases']}/{metrics['cases']}; "
                f"ASR-text parse {metrics['recognizedTextScoredCases']}/{metrics['cases']}"
            )


if __name__ == "__main__":
    main()
