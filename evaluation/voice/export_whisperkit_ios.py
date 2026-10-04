from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.spoken_wer import spoken_normalized_wer


def export_whisperkit_report(
    source: Path, output: Path, *, recognizer_prefix: str = "WhisperKit Core ML"
) -> dict[str, Any]:
    report = json.loads(source.read_text(encoding="utf-8"))
    mode = report["fixtureAudioMode"]
    variant = report["fixtureAudioVariant"]
    if mode not in ("guided-format", "reordered-format", "freeform-development", "voice-blind-v3") or variant not in (
        "clean",
        "noisy",
    ):
        raise ValueError("Expected a guided, reordered, freeform, or voice-blind audio set")
    manifest_path = AUDIO_OUTPUT_DIR / mode / "manifest.json"
    if report["fixtureAudioManifestSha256"] != file_sha256(manifest_path):
        raise ValueError("WhisperKit report and WAV manifest differ")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    cases = {entry["caseId"]: entry for entry in manifest["entries"]}
    rows = report["results"]
    if len(rows) != len(cases) or {row["id"] for row in rows} != set(cases):
        raise ValueError("WhisperKit report must cover each case exactly once")
    if any(row["locale"] != cases[row["id"]]["locale"] for row in rows):
        raise ValueError("WhisperKit report locale differs from WAV manifest")

    exported = []
    for row in rows:
        item: dict[str, Any] = {
            "caseId": row["id"],
            "locale": row["locale"],
            "variant": variant,
            "status": row["status"],
            "seconds": row["elapsedSeconds"],
        }
        if row["status"] == "ok":
            text = row["correctedText"]
            item["rawText"] = text
            item["correctedText"] = text
            item["rawWER"] = spoken_normalized_wer(cases[row["id"]]["ttsText"], text, row["locale"])
            item["correctedWER"] = item["rawWER"]
        else:
            item["reason"] = row.get("reason", "Unknown transcription failure")
        exported.append(item)

    result = {
        "schemaVersion": 1,
        "platform": "iOS",
        "recognizer": recognizer_prefix
        + " "
        + report.get("modelLabel", "large-v3-v20240930_626MB")
        + " on physical iPhone"
        + (" with type context" if report.get("promptMode", "none") == "type-context" else ""),
        "runId": report["runId"],
        "promptMode": report.get("promptMode", "none"),
        "sourceReportSha256": file_sha256(source),
        "modelLoadSeconds": report["modelLoadSeconds"],
        "availableMemoryBeforeLoadBytes": report.get("availableMemoryBeforeLoadBytes"),
        "availableMemoryAfterLoadBytes": report.get("availableMemoryAfterLoadBytes"),
        "minimumAvailableMemoryAfterTranscriptionBytes": report.get("minimumAvailableMemoryAfterTranscriptionBytes"),
        "audioMode": mode,
        "audioVariant": variant,
        "audioManifestSha256": report["fixtureAudioManifestSha256"],
        "results": exported,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="Export a physical-iPhone WhisperKit test as a voice ASR report")
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    report = export_whisperkit_report(args.source, args.output)
    for locale in ("en", "ru"):
        rows = [row for row in report["results"] if row["locale"] == locale]
        completed = [row for row in rows if row["status"] == "ok"]
        mean_wer = sum(row["correctedWER"] for row in completed) / len(completed) if completed else None
        print(f"{locale}: {len(completed)}/{len(rows)} WAV, mean WER {mean_wer}")


if __name__ == "__main__":
    main()
