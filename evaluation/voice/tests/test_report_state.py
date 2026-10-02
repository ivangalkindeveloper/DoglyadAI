from __future__ import annotations

import json
from pathlib import Path

from pytest import MonkeyPatch

from evaluation.voice import report


def test_running_evaluation_cannot_publish_previous_results(tmp_path: Path) -> None:
    summary = tmp_path / "summary.json"
    summary.write_text('{"requestedCases": 62}\n', encoding="utf-8")
    state = tmp_path / "run-state.json"
    state.write_text(json.dumps({"status": "running", "runId": "new"}), encoding="utf-8")

    assert report._read(summary) is None

    state.write_text(json.dumps({"status": "complete", "runId": "new"}), encoding="utf-8")
    assert report._read(summary) == {"requestedCases": 62}


def test_candidate_selection_ignores_incomplete_run_and_finds_token_suffix(
    tmp_path: Path, monkeypatch: MonkeyPatch
) -> None:
    monkeypatch.setattr(report, "OUTPUT_ROOT", tmp_path)
    monkeypatch.setattr(report, "_candidate_inputs_current", lambda result: result is not None)
    stale = tmp_path / "ios-candidate-device-extended-clean"
    stale.mkdir()
    (stale / "results.json").write_text('{"runId": "previous"}\n', encoding="utf-8")
    (stale / "run-state.json").write_text('{"status": "running"}\n', encoding="utf-8")
    application = json.loads(
        (report.ROOT / "backend/main/config/development/application.json").read_text(encoding="utf-8")
    )
    max_tokens = application["ultrasound"]["examinationNeuralModel"]["maxTokens"]
    current = tmp_path / f"ios-candidate-device-tokens{max_tokens}-extended-clean"
    current.mkdir()
    (current / "results.json").write_text('{"runId": "current"}\n', encoding="utf-8")

    assert report._candidate_directory("-extended-clean", physical_only=True) == current


def test_stale_source_cannot_satisfy_audio_gate(tmp_path: Path, monkeypatch: MonkeyPatch) -> None:
    (tmp_path / "results.json").write_text('{"runId": "old"}\n', encoding="utf-8")
    (tmp_path / "summary.json").write_text('{"requestedCases": 248}\n', encoding="utf-8")
    monkeypatch.setattr(report, "_candidate_inputs_current", lambda _: False)

    assert report._current_candidate_summary(tmp_path) is None
