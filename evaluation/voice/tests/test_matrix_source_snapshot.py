from pathlib import Path

from evaluation.voice.runners.matrix_source_snapshot import matrix_source_snapshot


def test_resume_fingerprint_tracks_code_and_config_but_not_user_ui_state(tmp_path: Path) -> None:
    source = tmp_path / "ios/App.swift"
    source.parent.mkdir()
    source.write_text("version one")
    baseline = matrix_source_snapshot(tmp_path)
    (source.parent / "UserInterfaceState.xcuserstate").write_text("unrelated window state")
    assert matrix_source_snapshot(tmp_path) == baseline
    source.write_text("version two")
    assert matrix_source_snapshot(tmp_path) != baseline
