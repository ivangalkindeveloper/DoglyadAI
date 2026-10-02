from __future__ import annotations

import json
from pathlib import Path

import pytest

from evaluation.voice import fact_diagnostic
from evaluation.voice.generate import file_sha256


def test_fact_diagnostic_checks_hash_and_flags_lost_side(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(fact_diagnostic, "TEXT_OUTPUT_DIR", tmp_path / "text")
    monkeypatch.setattr(fact_diagnostic, "AUDIO_OUTPUT_DIR", tmp_path / "audio")
    corpus = tmp_path / "text/freeformDevelopment.jsonl"
    corpus.parent.mkdir()
    corpus.write_text(
        json.dumps(
            {
                "id": "sample",
                "locale": "en",
                "expectedFacts": [
                    {"kind": "side", "value": "right"},
                    {"kind": "measurement", "value": 7, "unit": "mm"},
                    {"kind": "negation", "subject": "abnormality"},
                ],
            }
        )
        + "\n",
        encoding="utf-8",
    )
    manifest = tmp_path / "audio/freeform-development/manifest.json"
    manifest.parent.mkdir(parents=True)
    manifest.write_text(
        json.dumps({"split": "freeformDevelopment", "freeformDevelopmentSha256": file_sha256(corpus)}),
        encoding="utf-8",
    )
    report = tmp_path / "report.json"
    report.write_text(
        json.dumps(
            {
                "audioMode": "freeform-development",
                "audioVariant": "clean",
                "audioManifestSha256": file_sha256(manifest),
                "recognizer": "test",
                "results": [
                    {
                        "caseId": "sample",
                        "locale": "en",
                        "variant": "clean",
                        "status": "ok",
                        "correctedText": "kidney 7 mm no abnormality",
                        "correctedWER": 0.1,
                    }
                ],
            }
        ),
        encoding="utf-8",
    )

    result = fact_diagnostic.diagnose(report)
    assert result["byLocale"]["en"]["literalFactRetention"]["side"] == {"eligible": 1}
    assert result["byLocale"]["en"]["literalFactRetention"]["negation"] == {"eligible": 1, "retained": 1}
    assert result["byLocale"]["en"]["lostFactExamples"]["side"] == ["sample"]

    corpus.write_text("{}\n", encoding="utf-8")
    with pytest.raises(ValueError, match="corpus hashes differ"):
        fact_diagnostic.diagnose(report)
