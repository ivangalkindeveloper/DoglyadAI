from __future__ import annotations

import json
from pathlib import Path

import pytest

import evaluation.voice.v2_gate as v2_gate
from evaluation.voice.generate import file_sha256


def _summary(variant: str, audio_hash: str, *, count: int = 124) -> dict[str, object]:
    return {
        "platform": "iOS",
        "audioMode": "extended-v2",
        "audioVariant": variant,
        "audioManifestSha256": audio_hash,
        "regressionSha256": "text-hash",
        "systemVersion": "26.6.2",
        "deviceModel": "iPhone",
        "scoredCases": [
            {"id": f"{locale}-{index}", "locale": locale, "examinationTypeId": "echocardiography"}
            for locale in ("en", "ru")
            for index in range(count)
        ],
        "byLocale": {
            locale: {
                "cases": count,
                "speechAnalyzer": {
                    "scoredCases": count,
                    "asrStatuses": {"ok": count},
                    "parseStatuses": {"ok": count},
                    "equivalentExactCases": count,
                    "equivalentUnnoticedWrongFields": 0,
                },
            }
            for locale in ("en", "ru")
        },
    }


def test_v2_gate_requires_complete_matching_corpora(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    audio = tmp_path / "extended-v2"
    audio.mkdir()
    manifest = audio / "manifest.json"
    manifest.write_text("frozen", encoding="utf-8")
    monkeypatch.setattr(v2_gate, "AUDIO_OUTPUT_DIR", tmp_path)
    audio_hash = file_sha256(manifest)
    clean_path = tmp_path / "clean.json"
    noisy_path = tmp_path / "noisy.json"
    clean_path.write_text(json.dumps(_summary("clean", audio_hash)), encoding="utf-8")
    noisy_path.write_text(json.dumps(_summary("noisy", audio_hash)), encoding="utf-8")
    assert v2_gate.check_v2_gate(clean_path, noisy_path, tmp_path / "gate.json")["releaseReady"] is True

    noisy_path.write_text(json.dumps(_summary("noisy", audio_hash, count=123)), encoding="utf-8")
    with pytest.raises(ValueError, match="different cases"):
        v2_gate.check_v2_gate(clean_path, noisy_path, tmp_path / "gate.json")

    noisy = _summary("noisy", audio_hash)
    noisy["byLocale"]["ru"]["speechAnalyzer"]["equivalentUnnoticedWrongFields"] = 1
    noisy_path.write_text(json.dumps(noisy), encoding="utf-8")
    assert v2_gate.check_v2_gate(clean_path, noisy_path, tmp_path / "gate.json")["releaseReady"] is False
