from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.spoken_wer import spoken_normalized_wer


def export_device_asr(
    results_path: Path,
    *,
    mode: str,
    variant: str,
    engine: str = "speechAnalyzer",
    hints: bool = True,
    raw: bool = False,
) -> Path:
    if mode not in (
        "quick",
        "extended",
        "extended-v2",
        "voice-holdout",
        "guided-format",
        "reordered-format",
        "freeform-development",
    ) or variant not in (
        "clean",
        "noisy",
    ):
        raise ValueError("Unsupported audio selection")
    if mode == "quick" and variant != "clean":
        raise ValueError("Quick audio has no noisy variant")
    if engine not in ("speechAnalyzer", "sfSpeechRecognizer"):
        raise ValueError("Unknown iOS recognizer")
    original = json.loads(results_path.read_text(encoding="utf-8"))
    if original.get("fixtureAudioMode") != mode or original.get("fixtureAudioVariant") != variant:
        raise ValueError("iPhone report uses another audio mode or variant")
    manifest_path = AUDIO_OUTPUT_DIR / mode / "manifest.json"
    if original["fixtureAudioManifestSha256"] != file_sha256(manifest_path):
        raise ValueError("iPhone report and selected WAV manifest differ")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    entries = {entry["caseId"]: entry for entry in manifest["entries"]}
    rows = original["results"]
    if len(rows) != len(entries) or {row["id"] for row in rows} != set(entries):
        raise ValueError("iPhone report does not cover the selected audio set")

    exported: list[dict[str, Any]] = []
    key = f"{engine}/hints={str(hints).lower()}"
    for row in rows:
        entry = entries[row["id"]]
        if row["locale"] != entry["locale"]:
            raise ValueError("iPhone report locale differs from audio manifest")
        asr = row["asr"].get(key)
        if asr is None:
            raise ValueError(f"Missing iPhone ASR result: {key}")
        item = {"caseId": row["id"], "locale": row["locale"], "variant": variant, **asr}
        if raw and item["status"] == "ok":
            item["correctedText"] = item["rawText"]
        if item["status"] == "ok" and isinstance(entry.get("ttsText"), str):
            item["rawWER"] = spoken_normalized_wer(entry["ttsText"], item["rawText"], row["locale"])
            item["correctedWER"] = spoken_normalized_wer(entry["ttsText"], item["correctedText"], row["locale"])
        exported.append(item)

    report = {
        "schemaVersion": 1,
        "platform": "iOS",
        "recognizer": f"{engine} on physical iPhone; hints={str(hints).lower()}; text={'raw' if raw else 'corrected'}",
        "runId": original["runId"],
        "sourceReportSha256": file_sha256(results_path),
        "audioMode": mode,
        "audioVariant": variant,
        "audioManifestSha256": original["fixtureAudioManifestSha256"],
        "results": exported,
    }
    output = results_path.parent / f"asr-replay-{engine}-hints-{str(hints).lower()}-{'raw-' if raw else ''}report.json"
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description="Export fixed iPhone ASR transcripts for parser replay")
    parser.add_argument("results", type=Path)
    parser.add_argument(
        "--mode",
        choices=(
            "quick",
            "extended",
            "extended-v2",
            "voice-holdout",
            "guided-format",
            "reordered-format",
            "freeform-development",
        ),
        required=True,
    )
    parser.add_argument("--variant", choices=("clean", "noisy"), default="clean")
    parser.add_argument("--engine", choices=("speechAnalyzer", "sfSpeechRecognizer"), default="speechAnalyzer")
    parser.add_argument("--no-hints", action="store_true")
    parser.add_argument("--raw", action="store_true", help="Replay the recognizer text before lexicon correction")
    args = parser.parse_args()
    print(
        export_device_asr(
            args.results,
            mode=args.mode,
            variant=args.variant,
            engine=args.engine,
            hints=not args.no_hints,
            raw=args.raw,
        )
    )


if __name__ == "__main__":
    main()
