from __future__ import annotations

import json

import pytest

from evaluation.voice import compare_voice_holdout
from evaluation.voice.generate import file_sha256
from evaluation.voice.score_candidate import FIELDS


def _summary(mode: str, manifest_sha: str) -> dict:
    matches = dict.fromkeys(FIELDS, True)
    return {
        "audioMode": mode,
        "audioVariant": "clean",
        "regressionSha256": "corpus",
        "audioManifestSha256": manifest_sha,
        "scoredCases": [
            {
                "id": "case-1",
                "locale": "en",
                "examinationTypeId": "heart",
                "speechAnalyzerParseStatus": "ok",
                "speechAnalyzerCorrectedWER": 0.1,
                "speechAnalyzer": {
                    "equivalentExactCase": True,
                    "equivalentMatches": matches,
                    "equivalentUnnoticedWrongFields": [],
                },
            }
        ],
    }


def test_other_voice_comparison_requires_same_script(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(compare_voice_holdout, "AUDIO_OUTPUT_DIR", tmp_path)
    summaries = []
    for mode in ("extended-v2", "voice-holdout"):
        path = tmp_path / mode / "manifest.json"
        path.parent.mkdir()
        path.write_text(
            json.dumps({"entries": [{"caseId": "case-1", "locale": "en", "ttsText": "Same words."}]}),
            encoding="utf-8",
        )
        summaries.append(_summary(mode, file_sha256(path)))

    result = compare_voice_holdout.compare(*summaries)
    assert result["byLocale"]["en"]["originalEquivalentExact"] == 1
    assert result["byLocale"]["en"]["holdoutEquivalentExact"] == 1

    holdout_path = tmp_path / "voice-holdout" / "manifest.json"
    holdout_path.write_text(
        json.dumps({"entries": [{"caseId": "case-1", "locale": "en", "ttsText": "Different words."}]}),
        encoding="utf-8",
    )
    summaries[1]["audioManifestSha256"] = file_sha256(holdout_path)
    with pytest.raises(ValueError, match="script differs"):
        compare_voice_holdout.compare(*summaries)
