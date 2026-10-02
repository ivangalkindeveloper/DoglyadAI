from __future__ import annotations

from evaluation.voice.freeform_audio import tts_chunks, tts_script
from evaluation.voice.freeform_development import make_cases


def test_freeform_audio_script_preserves_correction_side_and_fact_order() -> None:
    cases = make_cases()
    complete = next(case for case in cases if case["locale"] == "en" and case["scenario"] == "complete")
    partial = next(case for case in cases if case["locale"] == "ru" and case["scenario"] == "partial")
    complete_script = tts_script(complete)
    partial_script = tts_script(partial)

    assert complete["expectedFields"]["patientName"] in complete_script
    assert "right" in complete_script
    assert "No additional abnormality" in complete_script
    assert "нет" in partial_script
    assert "patientName" not in partial["expectedFields"]
    assert len(tts_chunks(complete_script)) == 2
    assert " ".join(tts_chunks(partial_script)) == partial_script
