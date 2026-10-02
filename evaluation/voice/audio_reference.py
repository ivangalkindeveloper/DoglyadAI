from __future__ import annotations

import json
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.generate import file_sha256


def report_word_references(report: dict[str, Any]) -> dict[str, str]:
    """Return the frozen intended TTS words for a full-dictation iOS report.

    The reference is a script, not a human-verified transcription of the WAV.
    V1 reports keep their original regression text as the WER reference.
    """
    mode = report.get("fixtureAudioMode")
    if mode not in (
        "extended-v2",
        "voice-holdout",
        "phrase-holdout",
        "voice-blind-v3",
        "guided-format",
        "reordered-format",
        "freeform-development",
    ):
        return {}
    manifest_path = AUDIO_OUTPUT_DIR / mode / "manifest.json"
    if file_sha256(manifest_path) != report.get("fixtureAudioManifestSha256"):
        raise ValueError("iOS report uses another v2 audio manifest")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected_schema_version = 1 if mode == "freeform-development" else 2
    if manifest.get("schemaVersion") != expected_schema_version or manifest.get("mode") != mode:
        raise ValueError("Invalid full-dictation audio manifest")
    if manifest.get("regressionSha256") != report.get("fixtureRegressionSha256"):
        raise ValueError("V2 audio and text regression hashes differ")
    if manifest.get("split") == "control" and manifest.get("controlSha256") != report.get("fixtureControlSha256"):
        raise ValueError("Audio and text control hashes differ")
    if manifest.get("split") == "voiceBlind" and manifest.get("voiceBlindSha256") != report.get(
        "fixtureVoiceBlindSha256"
    ):
        raise ValueError("Audio and text blind hashes differ")
    if manifest.get("split") == "freeformDevelopment" and manifest.get("freeformDevelopmentSha256") != report.get(
        "fixtureFreeformDevelopmentSha256"
    ):
        raise ValueError("Audio and text freeform hashes differ")
    references: dict[str, str] = {}
    for entry in manifest["entries"]:
        case_id = entry["caseId"]
        if case_id in references or entry["status"] != "ok" or not entry.get("werReference"):
            raise ValueError(f"Invalid v2 word reference for {case_id}")
        references[case_id] = entry["werReference"]
    for row in report.get("results", []):
        if row["id"] not in references:
            raise ValueError(f"Missing v2 word reference for {row['id']}")
    return references
