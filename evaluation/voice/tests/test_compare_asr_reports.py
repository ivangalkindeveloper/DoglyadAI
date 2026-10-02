from __future__ import annotations

import json
from pathlib import Path

import pytest

import evaluation.voice.compare_asr_reports as comparison
from evaluation.voice.comparison import _critical_retention
from evaluation.voice.generate import file_sha256


def _report(text: str, *, audio_hash: str = "same") -> dict[str, object]:
    return {
        "audioManifestSha256": audio_hash,
        "audioMode": "extended",
        "results": [
            {
                "caseId": "case-1",
                "variant": "noisy",
                "locale": "en",
                "status": "ok",
                "correctedText": text,
                "correctedWER": 0.1,
            }
        ],
    }


def _compare(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, candidate_text: str, *, audio_hash: str = "same"
) -> dict[str, object]:
    corpus = tmp_path / "text"
    corpus.mkdir()
    (corpus / "regression.jsonl").write_text(
        json.dumps(
            {
                "id": "case-1",
                "locale": "en",
                "expectedFacts": [
                    {"kind": "side", "value": "right"},
                    {"kind": "measurement", "value": 7, "unit": "mm"},
                    {"kind": "negation", "value": "no"},
                ],
            }
        )
        + "\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(comparison, "TEXT_OUTPUT_DIR", corpus)
    baseline_path = tmp_path / "baseline.json"
    candidate_path = tmp_path / "candidate.json"
    baseline_path.write_text(json.dumps(_report("right kidney 7 mm no abnormality")), encoding="utf-8")
    candidate_path.write_text(json.dumps(_report(candidate_text, audio_hash=audio_hash)), encoding="utf-8")
    return comparison.compare_reports(baseline_path, candidate_path, tmp_path / "comparison.json")


def test_side_loss_blocks_asr_experiment(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    result = _compare(tmp_path, monkeypatch, "kidney 7 mm no abnormality")
    assert result["literalSideNegationGatePassed"] is False
    group = result["byLocaleAndVariant"]["en/noisy"]
    assert group["literalFactRegressions"]["side"] == ["case-1"]


def test_spelled_number_does_not_trigger_side_negation_gate(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    result = _compare(tmp_path, monkeypatch, "right kidney seven mm no abnormality")
    assert result["literalSideNegationGatePassed"] is True
    group = result["byLocaleAndVariant"]["en/noisy"]
    assert group["literalFactRegressions"]["number"] == ["case-1"]


def test_different_audio_is_not_compared(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    with pytest.raises(ValueError, match="different audio manifests"):
        _compare(tmp_path, monkeypatch, "right kidney 7 mm no abnormality", audio_hash="other")


def test_blind_corpus_is_used_for_a_paired_asr_comparison(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    text = tmp_path / "text"
    text.mkdir()
    blind = text / "voiceBlind.jsonl"
    blind.write_text(
        json.dumps(
            {
                "id": "case-1",
                "locale": "en",
                "expectedFacts": [{"kind": "side", "value": "right"}],
            }
        )
        + "\n",
        encoding="utf-8",
    )
    audio = tmp_path / "audio/voice-blind-v3"
    audio.mkdir(parents=True)
    manifest = audio / "manifest.json"
    manifest.write_text(json.dumps({"voiceBlindSha256": file_sha256(blind)}), encoding="utf-8")
    monkeypatch.setattr(comparison, "TEXT_OUTPUT_DIR", text)
    monkeypatch.setattr(comparison, "AUDIO_OUTPUT_DIR", tmp_path / "audio")
    baseline = _report("right kidney")
    baseline["audioMode"] = "voice-blind-v3"
    baseline["audioManifestSha256"] = file_sha256(manifest)
    candidate = _report("kidney")
    candidate["audioMode"] = "voice-blind-v3"
    candidate["audioManifestSha256"] = file_sha256(manifest)
    baseline_path = tmp_path / "baseline.json"
    candidate_path = tmp_path / "candidate.json"
    baseline_path.write_text(json.dumps(baseline), encoding="utf-8")
    candidate_path.write_text(json.dumps(candidate), encoding="utf-8")

    result = comparison.compare_reports(baseline_path, candidate_path, tmp_path / "comparison.json")
    assert result["byLocaleAndVariant"]["en/noisy"]["literalFactRegressions"]["side"] == ["case-1"]


def test_spoken_composite_units_are_retained_as_whole_phrases() -> None:
    case = {
        "expectedFacts": [
            {"kind": "measurement", "value": 75, "unit": "cm/s"},
        ]
    }
    assert _critical_retention(case, "75 centimeters per second")["unit"] is True
    assert _critical_retention(case, "75 centimeters")["unit"] is False
    russian = {"expectedFacts": [{"kind": "measurement", "value": 51, "unit": "мм"}]}
    assert _critical_retention(russian, "51 миллиметров")["unit"] is True
